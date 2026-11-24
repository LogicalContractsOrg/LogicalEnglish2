/** <module> Miniscript -> Logical English: the twin of a spending policy

    the design notes roadmap.md §6.4 (Phase 1d). A spending
    policy (miniscript.pl) becomes a migration (le_migration.pl): the
    Migration IR of an LE program saying when `the coin can be spent`, the
    ledger of what was mapped and how, and the source tests — the policy's
    own satisfaction analysis, each expected outcome computed by
    miniscript:ms_eval/2 on the policy tree, never by the LE program.

    ## The mapping

      pk(K), pkh(K), multi, ...    the witness contains a signature by <role>
      sha256/hash256/ripemd160/    the witness reveals the preimage of <name>
      hash160(H)
      older(n), blocks             the coin was confirmed in block F, the
                                   spending transaction is in block H, and
                                   block H is at least n blocks after block F
                                   (lib/temporal)
      older(n), BIP 68 time flag   the same with times, H - F >= 512 * n' s
      after(t)                     the spending transaction has the lock time
                                   L, the lock time L is a block height (or a
                                   time: lib/temporal) and L >= t
      and, or                      and, or — a top-level `or` is one rule per
                                   spending path, labelled and cited
      thresh(k, keys)              N is the count of each K such that K is in
                                   [the keys] and the witness contains a
                                   signature by K, and N >= k
      thresh(k, conditions)        the same count over named conditions, each
                                   with a rule of its own

    A twin: twin(Id, Options) with Options title(T), policy(Text),
    legend([KeyOrHash-Constant, ...]), paths([Label, ...]),
    source(Document, Url, TextFile, Quote), notes([Element-Note, ...]).
*/

:- module(ms_twin, [
    twin_migration/3,        % +Twin, +Dir, -Migration
    build_twin/3,            % +Twin, +Dir, -Report
    twin_policy/4,           % +Twin, -Policy, -Names, -NamedSets
    policy_file_text/2,      % +Twin, -Text  (the .policy original)
    key_loss/3               % +Policy, +Legend, -Rows
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(aggregate)).
:- use_module(miniscript).
:- use_module(ms_chain).
%   LE2 (le_writer, le_migration): the one this process runs in, the
%   environment's, or a checkout beside this repository (../le2_paths.pl
%   declares it as `le2`).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

%   The block and time at which a test's coin is confirmed.
base_height(850000).
base_time(1735689600).          % 2025-01-01T00:00:00Z

%   Bounds of the analysis: the number of spending paths turned into
%   scenarios, and the key-loss flips (which LE bounds at 3 changes).
max_paths(12).
max_keyloss_keys(6).

		 /*******************************
		 *         THE TWIN             *
		 *******************************/

%!  build_twin(+Twin, +Dir, -Report) is det.
%
%   Writes <Dir>/<Id>/<Id>.le with its ledger, the temporal library and the
%   cited source text.
build_twin(twin(Id, Opts), Root, Report) :-
    atomic_list_concat([Root, '/', Id], Dir),
    make_directory_path(Dir),
    copy_library(temporal, Dir),
    copy_source(Opts, Dir),
    copy_originals(Opts, Dir),
    write_policy_file(twin(Id, Opts), Dir),
    copy_chain_record(twin(Id, Opts), Dir),
    twin_migration(twin(Id, Opts), Dir, Migration),
    write_migration(Migration, Dir, Id, Report).

%   The pages and files the cited excerpts were taken from, whole (the
%   licensed ones with their licence), under sources/originals/.
copy_originals(Opts, Dir) :-
    (   option(source(_, _, TextFile, _), Opts), TextFile \== none
    ->  file_base_name(TextFile, B),
        forall(( original_of(B, Rel) ),
               ( source_dir(SrcDir), atomic_list_concat([SrcDir, '/originals/', Rel], Src),
                 atomic_list_concat([Dir, '/sources/originals/', Rel], Dst),
                 file_directory_name(Dst, DD), make_directory_path(DD),
                 copy_file(Src, Dst) ))
    ;   true
    ).

original_of('sipa_miniscript.txt', 'sipa_miniscript.html').
original_of('core_descriptors.txt', F) :- member(F, ['bitcoin_core/descriptors.md', 'bitcoin_core/COPYING']).
original_of('core_miniscript_tests.txt', F) :- member(F, ['bitcoin_core/miniscript_tests.cpp', 'bitcoin_core/COPYING']).
original_of('core_wallet_miniscript.txt', F) :- member(F, ['bitcoin_core/wallet_miniscript.py', 'bitcoin_core/COPYING']).
original_of('liana_readme.txt', F) :- member(F, ['liana/README.md', 'liana/LICENCE']).
original_of('liana_recover.txt', F) :- member(F, ['liana/RECOVER.md', 'liana/LICENCE']).

%   sources/<Id>.policy: the policy as File ▸ Open takes it back.
write_policy_file(Twin, Dir) :-
    Twin = twin(Id, _),
    policy_file_text(Twin, Text),
    format(atom(F), '~w/sources/~w.policy', [Dir, Id]),
    setup_call_cleanup(open(F, write, S, [encoding(utf8)]), write(S, Text), close(S)).

%   The recorded chain run (chain/runs/<Id>.tape.json), when there is one
%   for this very policy, as sources/<Id>.chain.json.
copy_chain_record(Twin, Dir) :-
    Twin = twin(Id, _),
    (   twin_chain_record(Twin, _)
    ->  runs_file(Id, Src),
        format(atom(Dst), '~w/sources/~w.chain.json', [Dir, Id]),
        copy_file(Src, Dst)
    ;   true
    ).

runs_file(Id, F) :- here(H), format(atom(F), '~w/chain/runs/~w.tape.json', [H, Id]).

twin_chain_record(twin(Id, Opts), Rec) :-
    chain_record(Id, tape, Rec),
    twin_policy(twin(Id, Opts), Policy, Names, _),
    placeholders(Policy, Names, Pl, _), ms_policy_text(Pl, PT),
    atom_string(PT, PS), Rec.policy == PS.

%!  twin_policy(+Twin, -Policy, -Names, -NamedSets) is det.
%
%   The lifted policy, the names of its keys and hashes, and the sampled
%   spending paths as Name-Set, each named after the rule it satisfies
%   (what the scenarios and the chain run are built from).
twin_policy(twin(_, Opts), Policy, Names, Named) :-
    option(policy(Text), Opts),
    ms_parse(Text, Tree), ms_policy(Tree, Policy),
    option(legend(Legend0), Opts, []),
    naming(Policy, Legend0, Names),
    ms_satisfactions(Policy, Sets0), sample_paths(Sets0, Sets),
    paths(Policy, Opts, Paths),
    named_sets(Paths, Sets, Named).

%!  named_sets(+Paths, +Sets, -Named) is det.
%
%   Each minimal satisfying set named after the rule (the top-level `or`
%   branch, Label-Branch in Paths) it satisfies — the first, when several
%   do: the scenario of rule `revocation` is `revocation`, and when a rule
%   has several minimal sets (an `or` or a `thresh` inside it) they are
%   `revocation_1`, `revocation_2`, ... So scenario and rule names agree,
%   whatever order the analysis finds the sets in.
named_sets(Paths, Sets, Named) :-
    maplist(set_rule(Paths), Sets, Labels),
    foldl(set_name(Labels), Labels, Sets, Named, []-[], _).

set_rule(Paths, Set, Label) :-
    state_for(Set, _, State),
    (   member(Label-Branch, Paths), holds_in(Branch, State) -> true
    ;   Label = path
    ).

set_name(All, Label, Set, Name-Set, Seen0-_, Seen-_) :-
    aggregate_all(count, member(Label, All), N),
    aggregate_all(count, member(Label, Seen0), K0), K is K0 + 1,
    Seen = [Label|Seen0],
    (   N =:= 1 -> Name = Label ; format(atom(Name), '~w_~w', [Label, K]) ).

%!  policy_file_text(+Twin, -Text) is det.
%
%   The `.policy` file of a twin (the format ms_import.pl reads): what the
%   source is and where it comes from, sipa's compilation of a policy, the
%   descriptor when the keys are real, the Minsc link, the key legend, and
%   the title just above the policy as the source writes it.
policy_file_text(twin(Id, Opts), Text) :-
    option(policy(PText0), Opts), ( atom(PText0) -> atom_string(PText0, PText) ; PText = PText0 ),
    option(title(Title), Opts, Id),
    option(source(Doc, Url, _, _), Opts, source(none, none, none, none)),
    twin_policy(twin(Id, Opts), Policy, Names, _),
    ms_parse(PText, Tree),
    findall(L, source_line(Doc, Url, L), SrcLines),
    (   policy_language(Tree), catch(ms_compile(PText, MS), _, fail)
    ->  format(string(C1), "# sipa's compiler (P2WSH) makes it the Miniscript:~n#     ~w", [MS]),
        (   all_real(Policy) -> format(string(C2), "~n# the descriptor:~n#     wsh(~w)", [MS]) ; C2 = "" ),
        string_concat(C1, C2, Compiled), CLines = [Compiled]
    ;   policy_language(Tree) -> CLines = []
    ;   CLines = ["# it is Miniscript (or a descriptor) as it stands."]
    ),
    (   catch(( minsc_code(Title, Policy, Names, Code), minsc_url(Code, MUrl) ), _, fail)
    ->  format(string(ML), "# try it in Minsc (policy -> Miniscript -> Script -> address, in the browser):~n#     ~w", [MUrl]),
        MLines = [ML]
    ;   MLines = []
    ),
    option(legend(Legend), Opts, []),
    findall(L, ( member(K-R, Legend), format(string(L), "~w = ~w", [K, R]) ), LLines),
    format(string(TL), "# ~w", [Title]),
    append([["# The spending policy of the Logical English twin " , "#"],
            SrcLines, ["#"], CLines, MLines,
            ["#", "# File > Open in the Logical English editor translates this file into the twin.", ""],
            LLines, ["", TL, PText, ""]], Lines0),
    Lines0 = [H1|Rest], format(string(H), "~w~w.", [H1, Id]),
    atomic_list_concat([H|Rest], '\n', TextA), atom_string(TextA, Text).

source_line(Doc, _, L) :- Doc \== none, format(string(L), "# source: ~w", [Doc]).
source_line(_, Url, L) :- Url \== none, format(string(L), "#         ~w", [Url]).

all_real(Policy) :-
    ms_keys(Policy, Ks), forall(member(K, Ks), ms_chain_real_key(K)),
    ms_hashes(Policy, Hs), forall(member(hash(Kind, H), Hs), ms_chain_real_hash(Kind, H)).

ms_chain_real_key(K) :- ms_chain:real_key(K).
ms_chain_real_hash(Kind, H) :- ms_chain:real_hash(Kind, H).

copy_source(Opts, Dir) :-
    (   option(source(_, _, TextFile, _), Opts), TextFile \== none
    ->  atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
        file_base_name(TextFile, B),
        atomic_list_concat([SD, '/', B], Dst),
        source_dir(SrcDir), atomic_list_concat([SrcDir, '/', B], Src),
        copy_file(Src, Dst)
    ;   true
    ).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).
source_dir(D) :- here(H), atomic_list_concat([H, '/sources'], D).

%!  twin_migration(+Twin, +Dir, -Migration) is det.
twin_migration(twin(Id, Opts), _Dir, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    option(policy(Text), Opts),
    option(title(Title), Opts, Id),
    ms_parse(Text, Tree),
    ms_policy(Tree, Policy),
    option(legend(Legend0), Opts, []),
    naming(Policy, Legend0, Names),
    option(source(Doc, Url, TextFile, Quote), Opts, source(none, none, none, none)),
    header_comment(Title, Doc, Url, Text, Tree, Policy, Names, HeaderComment0),
    (   minsc_link(Title, Policy, Names, MUrl)
    ->  format(string(HeaderComment), "~w~n~nTry it in Minsc (the policy compiled to Miniscript, Script and an address,~nin the browser): the document \"the policy in Minsc\" below.", [HeaderComment0]),
        ignore(MUrl = _)
    ;   HeaderComment = HeaderComment0
    ),
    Header = [kb(Id), comment(HeaderComment), includes([temporal])],
    features(Policy, Features),
    templates(Features, Templates),
    Prov = [as_stated_in(Doc), confer(Quote)],
    paths(Policy, Opts, Paths),
    option(quotes(PathQuotes), Opts, []),            % a path's own passage, when the source has one
    path_rules(Paths, Names, Prov-PathQuotes, Rules, Conditions),
    documents(Doc, Url, TextFile, Docs0),
    minsc_document(Title, Policy, Names, MinscDocs),
    twin_policy(twin(Id, Opts), _, _, NamedSets),
    (   twin_chain_record(twin(Id, Opts), Rec)
    ->  chain_tests(Rec, Names-NamedSets, Features, Id, ChainTests-ChainDoc-_), ChainDocs = [ChainDoc]
    ;   ChainTests = [], ChainDocs = []
    ),
    append([Docs0, MinscDocs, ChainDocs], Docs),
    tests(Id, Policy, Names, Features, NamedSets, Tests0),
    flip_tests(Policy, Names, Features, FlipTests, FlipQueries),
    append([Tests0, FlipTests, ChainTests], Tests),
    queries(FlipQueries, Queries0),
    key_facts(Policy, Names, KeyTemplates, KeyFacts),
    key_queries(KeyTemplates, KeyQueries),
    append(Queries0, KeyQueries, Queries),
    view(Title, Features, View),
    age_rules(Features, Ages),
    append([Templates, KeyTemplates, Docs, KeyFacts, [comment("The spending paths of the policy.")], Rules,
            Conditions, Ages, Queries, [View]], Items),
    ledger(Tree, Policy, Paths, Names, Features, Opts, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source(Title), artifacts([Url]),
            translator('LE2 migration/miniscript (ms_twin.pl)'), date(Date)].

%   The keys and hashes as the source writes them (the real ones), and the
%   hash function of each hash lock: what a descriptor needs, stated in the
%   program, so that File ▸ Export writes the policy back with its keys.
key_facts(Policy, Names, Templates, Facts) :-
    findall(fact(public_key(C, KS), []),
            ( member(pk(K)-C, Names), ms_chain:real_key(K), atom_string(K, KS) ), KFs),
    findall(fact(hash_function(C, F), []),
            ( member(hash(H)-C, Names), sub(Policy, hash(F, H)) ), HFs0), list_to_set(HFs0, HFs),
    findall(fact(hash_value(C, HS), []),
            ( member(hash(H)-C, Names), sub(Policy, hash(F, H)), ms_chain:real_hash(F, H), atom_string(H, HS) ), HVs0),
    list_to_set(HVs0, HVs),
    findall(T, ( KFs \== [], T = template(public_key, "the public key of *a key* is *a text*", [])
               ; HFs \== [], T = template(hash_function, "the hash function of *a hash* is *a function*", [])
               ; HVs \== [], T = template(hash_value, "the hash value of *a hash* is *a text*", []) ), Templates),
    append([KFs, HFs, HVs], Fs0),
    (   Fs0 == [] -> Facts = []
    ;   Facts = [comment("The keys and hashes of the policy, as the source writes them.")|Fs0]
    ).

%   The policy in the Minsc playground, as a document the program cites
%   by address (the editor shows it as a link); none when the Minsc tools
%   (chain/node_modules) are not installed.
minsc_document(Title, Policy, Names, [document('the policy in Minsc', [url(Url)])]) :-
    minsc_link(Title, Policy, Names, Url), !.
minsc_document(_, _, _, []).

minsc_link(Title, Policy, Names, Url) :-
    catch(( minsc_code(Title, Policy, Names, Code), minsc_url(Code, Url) ), _, fail).

		 /*******************************
		 *    THE SOURCE, IN THE HEADER *
		 *******************************/

%   The header shows the source four ways, so a reader sees at a glance
%   what it said: verbatim; laid out as an indented tree of its own
%   notation with keys and hashes by role; the legend from roles to the
%   keys and hashes as written; and what it says, in words.
header_comment(Title, Doc, Url, Text, Tree, Policy, Names, Comment) :-
    ( atom(Text) -> atom_string(Text, TextS) ; TextS = Text ),
    verbatim_lines(TextS, VLines, Cut),
    findall(K-C, member(pk(K)-C, Names), KL), findall(H-C, member(hash(H)-C, Names), HL),
    append(KL, HL, Labels),
    ms_layout(Tree, Labels, TLines),
    legend_lines(Names, LLines),
    policy_words(Policy, Names, WLines),
    (   Cut == true
    ->  VHead = "The source, as written (cut into lines of 100 characters: join them for the text):"
    ;   VHead = "The source, as written:"
    ),
    (   Doc == none -> SrcLines = []
    ;   Url == none -> format(string(S1), "Source: ~w", [Doc]), SrcLines = ["", S1]
    ;   format(string(S1), "Source: ~w", [Doc]), format(string(S2), "        ~w", [Url]),
        SrcLines = ["", S1, S2]
    ),
    maplist(indented, VLines, VL), maplist(indented, TLines, TL),
    maplist(indented, LLines, LL), maplist(indented, WLines, WL),
    ms_lock_warnings(Policy, Warnings),
    (   Warnings == [] -> WarnLines = []
    ;   findall(L, ( member(W, Warnings), format(string(L), "    WARNING: ~w.", [W]) ), WLs),
        append([["", "What consensus reads otherwise (the twin states what consensus reads):"], WLs], WarnLines)
    ),
    (   sub_term(p(_, _), Tree)
    ->  WeightLines = ["", "The weights (like 99@) guide sipa's compiler towards the likelier paths;",
                       "they do not change who can spend, and the twin leaves them out."]
    ;   WeightLines = []
    ),
    append([[Title, "",
             "The Logical English twin of a Bitcoin spending policy, written by the",
             "Miniscript translator. Who can spend the",
             "coin, when, and why: each rule is one spending path of the policy."],
            WarnLines,
            SrcLines,
            ["", VHead], VL,
            ["", "The source, laid out (keys and hashes by their role, <like this>):"], TL,
            ["", "The legend (role <- key or hash as written in the source):"], LL,
            ["", "What it says (the spending policy, by BIP 379's semantics):"], WL, WeightLines],
           Lines),
    atomic_list_concat(Lines, '\n', CA), atom_string(CA, Comment).

indented(L, S) :- string_concat("    ", L, S).

verbatim_lines(Text, Lines, Cut) :-
    string_length(Text, N),
    (   N =< 100 -> Lines = [Text], Cut = false
    ;   Cut = true, chunks(Text, 100, Lines)
    ).

chunks(T, W, [T]) :- string_length(T, N), N =< W, !.
chunks(T, W, [C|Cs]) :- sub_string(T, 0, W, _, C), sub_string(T, W, _, 0, R), chunks(R, W, Cs).

legend_lines(Names, Lines) :-
    findall(C, member(_-C, Names), Cs),
    aggregate_all(max(L), ( member(C, Cs), atom_length(C, L) ), Max),
    findall(pk(K)-C, member(pk(K)-C, Names), KN), findall(hash(H)-C, member(hash(H)-C, Names), HN),
    append(KN, HN, Ordered),
    findall(Line, ( member(E-C, Ordered), legend_leaf(E, Leaf),
                    atom_length(C, L), Pad is Max - L, length(Sp, Pad), maplist(=(0' ), Sp),
                    atom_codes(SpA, Sp),
                    format(string(Line), "~w~w <- ~w", [C, SpA, Leaf]) ),
            Lines).

legend_leaf(pk(K), K).
legend_leaf(hash(H), H).

%   The policy in words: all of / any one of / at least k of, nested.
policy_words(P, Names, Lines) :- words(P, Names, 0, Lines0), maplist(indent_pair, Lines0, Lines).

indent_pair(I-T, L) :- length(Sp, I), maplist(=(0' ), Sp), string_codes(S, Sp), string_concat(S, T, L).

words(and(A, B), Names, I, [I-"all of these:"|Ls]) :- !,
    conj_items(and(A, B), Items), sub_words(Items, Names, I, Ls).
words(or(A, B), Names, I, [I-"any one of these:"|Ls]) :- !,
    disj_items(or(A, B), Items), sub_words(Items, Names, I, Ls).
words(thresh(K, Ps), Names, I, [I-H|Ls]) :- !,
    length(Ps, N), format(string(H), "at least ~w of these ~w:", [K, N]),
    sub_words(Ps, Names, I, Ls).
words(P, Names, I, [I-T]) :- leaf_words(P, Names, T).

sub_words(Items, Names, I, Lines) :-
    I1 is I + 2,
    items_words(Items, Names, I1, Lines).

items_words([], _, _, []).
items_words([P|Ps], Names, I, Lines) :-
    words(P, Names, I, L1), items_words(Ps, Names, I, L2), append(L1, L2, Lines).

conj_items(and(A, B), Is) :- !, conj_items(A, IA), conj_items(B, IB), append(IA, IB, Is).
conj_items(P, [P]).
disj_items(or(A, B), Is) :- !, disj_items(A, IA), disj_items(B, IB), append(IA, IB, Is).
disj_items(P, [P]).

leaf_words(true, _, "nothing: anyone can spend") :- !.
leaf_words(false, _, "impossible: no one can spend") :- !.
leaf_words(pk(K), Names, T) :- !, name_of(Names, pk(K), C), format(string(T), "a signature by ~w", [C]).
leaf_words(hash(F, H), Names, T) :- !, name_of(Names, hash(H), C),
    format(string(T), "the preimage of ~w (~w)", [C, F]).
leaf_words(older(N), _, T) :-
    ms_older_blocks(N, B), integer(B), !,
    duration_words(B * 600, D),
    format(string(T), "the coin at least ~w blocks old (~w; older(~w))", [B, D, N]).
leaf_words(older(N), _, T) :- !,
    ms_older_blocks(N, seconds(S)), duration_words(S, D),
    format(string(T), "the coin at least ~w seconds old (~w; older(~w))", [S, D, N]).
leaf_words(after(N), _, T) :- N < 500000000, !,
    format(string(T), "a lock time of block height ~w or later (after(~w))", [N, N]).
leaf_words(after(N), _, T) :- !,
    format_time(string(D), '%Y-%m-%d %H:%M UTC', N),
    format(string(T), "a lock time of ~w or later (after(~w))", [D, N]).
leaf_words(P, _, T) :- format(string(T), "~w", [P]).

%   Seconds as words; blocks are counted at the network's ten-minute average.
duration_words(Secs0, W) :-
    Secs is Secs0,
    (   Secs < 7200 -> M is round(Secs / 60), format(string(W), "about ~w minutes", [M])
    ;   Secs < 172800 -> H is round(Secs / 3600), format(string(W), "about ~w hours", [H])
    ;   D is round(Secs / 86400), format(string(W), "about ~w days", [D])
    ).

		 /*******************************
		 *        NAMES OF THINGS       *
		 *******************************/

%   Names: [pk(Key)-Constant, hash(H)-Constant]: the legend's, else `key A`,
%   `key B`, ... and `secret 1`, ... in order of appearance.
naming(Policy, Legend, Names) :-
    ms_keys(Policy, Keys),
    ms_hashes(Policy, Hashes),
    foldl(name_key(Legend), Keys, 0-[], _-KN),
    foldl(name_hash(Legend), Hashes, 0-[], _-HN),
    append(KN, HN, Names0), reverse(Names0, Names).

name_key(Legend, K, I0-Acc, I-[pk(K)-C|Acc]) :-
    I is I0 + 1,
    (   legend_name(Legend, K, C0) -> C = C0
    ;   Letter is 0'A + I0, format(atom(C), 'key ~c', [Letter])
    ).

name_hash(Legend, hash(_, H), I0-Acc, I-[hash(H)-C|Acc]) :-
    I is I0 + 1,
    (   legend_name(Legend, H, C0) -> C = C0
    ;   format(atom(C), 'secret ~w', [I])
    ).

legend_name(Legend, K, C) :-
    member(L-C, Legend),
    (   L == K -> true
    ;   atom(K), atom(L), sub_atom(K, _, _, _, L)     % a fingerprint or prefix names the key
    ), !.

name_of(Names, T, C) :- memberchk(T-C, Names).

		 /*******************************
		 *          TEMPLATES           *
		 *******************************/

%   What the policy uses: sigs, preimages, older_blocks, older_time,
%   after_height, after_time, thresh_conditions.
features(P, Fs) :-
    findall(F, feature(P, F), Fs0), sort(Fs0, Fs).

feature(P, sigs) :- ms_keys(P, [_|_]).
feature(P, preimages) :- ms_hashes(P, [_|_]).
feature(P, older_blocks) :- sub(P, older(N)), ms_older_blocks(N, B), integer(B).
feature(P, older_time) :- sub(P, older(N)), ms_older_blocks(N, seconds(_)).
feature(P, after_height) :- sub(P, after(N)), N < 500000000.
feature(P, after_time) :- sub(P, after(N)), N >= 500000000.
feature(P, thresh_conditions) :- sub(P, thresh(_, Ps)), \+ all_keys(Ps).

sub(P, P).
sub(and(A, B), S) :- ( sub(A, S) ; sub(B, S) ).
sub(or(A, B), S) :- ( sub(A, S) ; sub(B, S) ).
sub(thresh(_, Ps), S) :- member(P, Ps), sub(P, S).

all_keys(Ps) :- forall(member(P, Ps), P = pk(_)).

templates(Fs, Ts) :-
    findall(T, ( member(F, Fs), feature_template(F, T) ), T00), list_to_set(T00, T0),
    append([[template(spendable, "the coin can be spent", [])], T0], Ts).

feature_template(sigs, template(sig, "the witness contains a signature by *a key*", [undefined])).
feature_template(preimages, template(pre, "the witness reveals the preimage of *a hash*", [undefined])).
feature_template(older_blocks, template(confirmed, "the coin was confirmed in block *a height*", [undefined])).
feature_template(older_blocks, template(spent_in, "the spending transaction is in block *a height*", [undefined])).
feature_template(older_blocks, template(age_blocks, "the coin has been confirmed for *a number* blocks", [])).
feature_template(older_time, template(confirmed_at, "the coin was confirmed at the time *a time*", [undefined])).
feature_template(older_time, template(spent_at, "the spending transaction is at the time *a time*", [undefined])).
feature_template(older_time, template(age_seconds, "the coin has been confirmed for *a number* seconds", [])).
feature_template(F, template(locktime, "the spending transaction has the lock time *a number*", [undefined])) :-
    F == after_height.
feature_template(after_time, template(locktime, "the spending transaction has the lock time *a number*", [undefined])).
feature_template(after_height, template(lock_height, "the lock time *a number* is a block height", [included])).
feature_template(after_height, template(spent_in, "the spending transaction is in block *a height*", [undefined])).
feature_template(after_time, template(spent_at, "the spending transaction is at the time *a time*", [undefined])).
feature_template(after_time, template(lock_time, "the lock time *a number* is a time", [included])).
feature_template(thresh_conditions, template(met, "the condition *a condition* is met", [])).

		 /*******************************
		 *            RULES             *
		 *******************************/

%   The spending paths: the top-level `or` branches, labelled.
paths(Policy, Opts, Paths) :-
    or_branches(Policy, Bs),
    option(paths(Labels0), Opts, []),
    length(Bs, N),
    numlist(1, N, Is),
    maplist(path_label(Labels0), Is, Labels),
    pairs_keys_values(Paths, Labels, Bs).

or_branches(or(A, B), Bs) :- !, or_branches(A, BA), or_branches(B, BB), append(BA, BB, Bs).
or_branches(P, [P]).

path_label(Labels, I, L) :-
    ( nth1(I, Labels, L0) -> L = L0 ; format(atom(L), 'path_~w', [I]) ).

path_rules(Paths, Names, Prov, Rules, Conds) :-
    foldl(path_rule(Names, Prov), Paths, 1-[], _-Pairs),
    reverse(Pairs, Pairs1),
    pairs_keys_values(Pairs1, Rules, CondLists),
    append(CondLists, Conds).

path_rule(Names, Prov0-Quotes, Label-P, T0-Acc, T-[rule(spendable, Body, [label(Label), provenance(Prov)])-Conds|Acc]) :-
    (   memberchk(Label-Q, Quotes), Prov0 = [D, _] -> Prov = [D, confer(Q)] ; Prov = Prov0 ),
    body(P, Names, Label, Prov, T0, T, Body0, Conds),
    left_assoc(Body0, Body).

%   and(A, and(B, C)) as and(and(A, B), C): the way LE reads sibling lines,
%   so a conjunction is written as a flat list of conditions.
left_assoc(B, L) :-
    (   B = and(_, _) -> Op = and ; B = or(_, _) -> Op = or ), !,
    chain(B, Op, Items0),
    maplist(left_assoc, Items0, [First|Rest]),
    foldl(join(Op), Rest, First, L).
left_assoc(agg(O, E, G0, R), agg(O, E, G, R)) :- !, left_assoc(G0, G).
left_assoc(B, B).

chain(B, Op, Items) :-
    (   B =.. [Op, X, Y] -> chain(X, Op, IX), chain(Y, Op, IY), append(IX, IY, Items)
    ;   Items = [B]
    ).

join(Op, I, Acc, New) :- New =.. [Op, Acc, I].

%!  body(+Policy, +Names, +Label, +Prov, +T0, -T, -Body, -ExtraRules)
%
%   T threads a counter naming the conditions of heterogeneous thresholds.
body(pk(K), Names, _, _, T, T, sig(C), []) :- !, name_of(Names, pk(K), C).
body(hash(_, H), Names, _, _, T, T, pre(C), []) :- !, name_of(Names, hash(H), C).
body(older(N), _, _, _, T, T, and(age_blocks(A), A >= B), []) :-
    ms_older_blocks(N, B), integer(B), !.
body(older(N), _, _, _, T, T, and(age_seconds(A), A >= S), []) :- !,
    ms_older_blocks(N, seconds(S)).
body(after(N), _, _, _, T, T, and(and(and(and(locktime(L), Kind), L >= N), Now), L < M), []) :- !,
    ( N < 500000000 -> Kind = lock_height(L), Now = spent_in(M) ; Kind = lock_time(L), Now = spent_at(M) ).
body(and(A, B), Names, L, Pv, T0, T, and(BA, BB), R) :- !,
    body(A, Names, L, Pv, T0, T1, BA, RA), body(B, Names, L, Pv, T1, T, BB, RB), append(RA, RB, R).
body(or(A, B), Names, L, Pv, T0, T, or(BA, BB), R) :- !,
    body(A, Names, L, Pv, T0, T1, BA, RA), body(B, Names, L, Pv, T1, T, BB, RB), append(RA, RB, R).
body(thresh(K, Ps), Names, _, _, T, T, and(agg(count, Key, and(member(Key, Cs), sig(Key)), N), N >= K), []) :-
    all_keys(Ps), !,
    findall(C, ( member(pk(Key0), Ps), name_of(Names, pk(Key0), C) ), Cs).
body(thresh(K, Ps), Names, L, Pv, T0, T, and(agg(count, C, and(member(C, CNames), met(C)), N), N >= K), Rules) :-
    T1 is T0 + 1,
    length(Ps, NP), numlist(1, NP, Is),
    maplist(condition_name(Names, T0), Is, Ps, CNames),
    maplist(triple, Is, Ps, CNames, Triples),
    foldl(condition_rules(Names, L, Pv, T0), Triples, T1-[], T-RulesRev),
    reverse(RulesRev, RuleLists), append(RuleLists, Rules).

%   The name of a threshold's condition: what it asks for.
condition_name(Names, _, _, pk(K), C) :- !, name_of(Names, pk(K), R), format(atom(C), 'the signature of ~w', [R]).
condition_name(Names, _, _, hash(_, H), C) :- !, name_of(Names, hash(H), R), format(atom(C), 'the preimage of ~w', [R]).
condition_name(_, _, _, older(N), C) :- ms_older_blocks(N, B), integer(B), !, format(atom(C), 'the delay of ~w blocks', [B]).
condition_name(_, _, _, older(N), C) :- !, ms_older_blocks(N, seconds(S)), format(atom(C), 'the delay of ~w seconds', [S]).
condition_name(_, _, _, after(N), C) :- N < 500000000, !, format(atom(C), 'the lock at block ~w', [N]).
condition_name(_, _, _, after(N), C) :- !, format(atom(C), 'the lock at time ~w', [N]).
condition_name(_, T, I, _, C) :- format(atom(C), 'condition ~w of threshold ~w', [I, T]).

triple(I, P, C, I-P-C).

condition_rules(Names, L, Pv, Tn, I-P-CName, T0-Acc, T-[[rule(met(CName), B, [label(Lab), provenance(Pv)])|R]|Acc]) :-
    (   Tn =:= 1 -> format(atom(Lab), '~w_condition_~w', [L, I])
    ;   format(atom(Lab), '~w_threshold_~w_condition_~w', [L, Tn, I])
    ),
    body(P, Names, L, Pv, T0, T1, B0, R), left_assoc(B0, B),
    T is max(T0, T1) + 1.

%   The coin's age, from the block (or time) it was confirmed in and the
%   block (or time) of the transaction spending it: what older(n) — BIP 68's
%   relative lock — measures.
age_rules(Fs, Rules) :-
    findall(R, age_rule(Fs, R), Rules0),
    ( Rules0 == [] -> Rules = [] ; Rules = [comment("The age of the coin, which the relative timelocks (older) measure.")|Rules0] ).

age_rule(Fs, rule(age_blocks(A), and(and(confirmed(F), spent_in(H)), A is H - F), [label(coin_age_in_blocks)])) :-
    memberchk(older_blocks, Fs).
age_rule(Fs, rule(age_seconds(A), and(and(confirmed_at(F), spent_at(H)), A is H - F), [label(coin_age_in_seconds)])) :-
    memberchk(older_time, Fs).

documents(Doc, Url, TextFile, Docs) :-
    (   Doc == none -> Docs = []
    ;   findall(O, ( Url \== none, O = url(Url) ; TextFile \== none, file_base_name(TextFile, B),
                                     atomic_list_concat(['sources/', B], P), O = text(P) ), Os),
        Docs = [document(Doc, Os)]
    ).

		 /*******************************
		 *   THE SATISFACTION ANALYSIS  *
		 *******************************/

%   A test state: s(Sigs, Preimages, Age, Seconds, LockTime) — Age the
%   coin's age in blocks at spending, Seconds in seconds, LockTime the
%   spending transaction's (0 when the policy has an after() the state does
%   not meet).
tests(Id, Policy, Names, Fs, NamedSets, Tests) :-
    findall(T, ( member(Name-S, NamedSets), path_tests(Id, Name, S, Policy, Names, Fs, T) ), Tests0),
    empty_test(Id, Policy, Names, Fs, Empty),
    append(Tests0, [Empty], Tests).

%   At most max_paths/1 paths: every one when there are few, else a
%   deterministic spread (first, last and evenly in between).
sample_paths(Sets, Sample) :-
    max_paths(Max), length(Sets, N),
    (   N =< Max -> Sample = Sets
    ;   Step is N / Max,
        findall(S, ( between(0, Max, J), J < Max, I is floor(J * Step) + 1, nth1(I, Sets, S) ), S0),
        last(Sets, L), append(S0, [L], S1), list_to_set(S1, Sample)
    ).

path_tests(Id, I, Set, Policy, Names, Fs, T) :-
    format(atom(Loc), 'spending path ~w', [I]),       % I: the name of the rule it satisfies
    state_for(Set, Policy, State),
    (   T = test(Tid, Doc, none, Facts, [expects(spendable, Ans)]),
        Tid = I, analysis_doc(Id, Doc),
        state_facts(State, Names, Fs, Facts0), answer(Policy, State, Ans),
        located(Loc, Set, Names, Facts0, Facts)
    ;   nth1(J, Set, El), near_miss(El, Set, Policy, State, State1),
        format(atom(Tid), '~w_without_~w', [I, J]),
        format(atom(Loc1), 'spending path ~w without requirement ~w', [I, J]),
        analysis_doc(Id, Doc1),
        T = test(Tid, Doc1, none, Facts1, [expects(spendable, Ans1)]),
        state_facts(State1, Names, Fs, Facts10), answer(Policy, State1, Ans1),
        located(Loc1, Set, Names, Facts10, Facts1)
    ).

analysis_doc(_, 'the satisfaction analysis of the policy').
flip_doc('the flip analysis of the policy').

empty_test(Id, Policy, Names, Fs, test(no_witness, Doc, none, [comment("an empty witness")|Facts], [expects(spendable, Ans)])) :-
    analysis_doc(Id, Doc),
    State = s([], [], 0, 0, 0),
    state_facts(State, Names, Fs, Facts),
    answer(Policy, State, Ans).

%   The test's place in the analysis, as a comment opening the scenario
%   (the source locator; see the README on why it is not the header's).
located(Loc, Set, Names, Facts, [comment(C)|Facts]) :-
    maplist(requirement_words(Names), Set, Ws),
    atomic_list_concat(Ws, ', ', W),
    format(string(C), "~w — the path needs: ~w", [Loc, W]).

requirement_words(Names, sig(K), W) :- name_of(Names, pk(K), C), format(atom(W), 'a signature by ~w', [C]).
requirement_words(Names, preimage(H), W) :- name_of(Names, hash(H), C), format(atom(W), 'the preimage of ~w', [C]).
requirement_words(_, older(N), W) :- ms_older_blocks(N, B), ( integer(B) -> format(atom(W), 'a coin ~w blocks old', [B]) ; B = seconds(S), format(atom(W), 'a coin ~w seconds old', [S]) ).
requirement_words(_, after(N), W) :- format(atom(W), 'a lock time of at least ~w', [N]).

%   The state that meets exactly the requirements of a set.
state_for(Set, _Policy, s(Sigs, Pres, Age, Secs, Lock)) :-
    findall(K, member(sig(K), Set), Sigs),
    findall(H, member(preimage(H), Set), Pres),
    findall(B, ( member(older(N), Set), ms_older_blocks(N, B), integer(B) ), Bs), max_or_zero(Bs, Age),
    findall(S, ( member(older(N), Set), ms_older_blocks(N, seconds(S)) ), Ss), max_or_zero(Ss, Secs),
    findall(A, member(after(A), Set), As), max_or_zero(As, Lock).

max_or_zero([], 0) :- !.
max_or_zero(L, M) :- max_list(L, M).

%   The state one requirement short of the set: the signature or the
%   preimage missing, a delay one block (one second) short, a lock time one
%   below.
near_miss(sig(K), _, _, s(S, P, A, T, L), s(S1, P, A, T, L)) :- delete(S, K, S1).
near_miss(preimage(H), _, _, s(S, P, A, T, L), s(S, P1, A, T, L)) :- delete(P, H, P1).
near_miss(older(N), _, _, s(S, P, _, T, L), s(S, P, A1, T, L)) :-
    ms_older_blocks(N, B), integer(B), !, A1 is B - 1.
near_miss(older(N), _, _, s(S, P, A, _, L), s(S, P, A, T1, L)) :-
    ms_older_blocks(N, seconds(Sec)), T1 is Sec - 1.
near_miss(after(N), _, _, s(S, P, A, T, _), s(S, P, A, T, L1)) :- L1 is N - 1.

%   The expected answer, from the policy's own semantics.
answer(Policy, State, Ans) :-
    (   holds_in(Policy, State) -> Ans = [spendable] ; Ans = [] ).

attempt_of(s(Sigs, Pres, Age, Secs, Lock), attempt(Sigs, Pres, rel(Age, Secs), Lock)).

holds_in(Policy, State) :- attempt_of(State, A), ms_eval(Policy, A).

state_facts(State, Names, Fs, Facts) :-
    State = s(Sigs, Pres, Age, Secs, Lock),
    findall(sig(C), ( member(K, Sigs), name_of(Names, pk(K), C) ), F1),
    findall(pre(C), ( member(H, Pres), name_of(Names, hash(H), C) ), F2),
    %  the spend comes after its lock time (a transaction whose lock time
    %  is not yet past cannot be mined), so the coin's block moves up when a
    %  lock time is later than the base
    base_height(B00), base_time(T00),
    (   Lock > 0, Lock < 500000000 -> B0 is max(B00, Lock + 1 - Age) ; B0 = B00 ),
    (   Lock >= 500000000 -> T0 is max(T00, Lock + 1 - Secs) ; T0 = T00 ),
    B1 is B0 + Age, T1 is T0 + Secs,
    (   memberchk(older_blocks, Fs) -> F3 = [confirmed(B0), spent_in(B1)]
    ;   memberchk(after_height, Fs) -> F3 = [spent_in(B1)]
    ;   F3 = []
    ),
    (   memberchk(older_time, Fs) -> F4 = [confirmed_at(T0), spent_at(T1)]
    ;   memberchk(after_time, Fs) -> F4 = [spent_at(T1)]
    ;   F4 = []
    ),
    (   ( memberchk(after_height, Fs) ; memberchk(after_time, Fs) ) -> F5 = [locktime(Lock)] ; F5 = [] ),
    append([F1, F2, F3, F4, F5], Facts).

		 /*******************************
		 *     FLIPS: WHAT IT TAKES     *
		 *******************************/

%   Flip tests: what minimal change lets the coin be spent now, and after
%   every delay; and, per key (key-loss analysis), with that key's
%   signature missing and everything else given, what minimal removal would
%   stop the coin being spent — the keys and facts that become
%   indispensable once that key is lost.
flip_tests(Policy, Names, Fs, Tests, [flip_spend, flip_block]) :-
    ms_satisfactions(Policy, Sets),
    State0 = s([], [], 0, 0, 0),
    all_delays(Policy, Sets, Later),
    add_test(flip_now, 'nothing signed, no delay passed', State0, Policy, Sets, Names, Fs, T1),
    add_test(flip_after_delays, 'nothing signed, every delay passed', Later, Policy, Sets, Names, Fs, T2),
    ms_keys(Policy, Keys),
    length(Keys, NK), max_keyloss_keys(MaxK),
    (   NK =< MaxK
    ->  findall(T, ( member(K, Keys), keyloss_test(K, Later, Policy, Names, Fs, T) ), KT)
    ;   KT = []
    ),
    append([[T1, T2], KT], Tests).

all_delays(Policy, Sets, s([], [], Age, Secs, Lock)) :-
    findall(R, ( member(S, Sets), member(R, S) ), Rs),
    findall(B, ( member(older(N), Rs), ms_older_blocks(N, B), integer(B) ), Bs), max_or_zero(Bs, Age),
    findall(X, ( member(older(N), Rs), ms_older_blocks(N, seconds(X)) ), Xs), max_or_zero(Xs, Secs),
    %  a lock time of the kind most after()s use, meeting all of them
    findall(A, member(after(A), Rs), As),
    (   As == [] -> Lock = 0
    ;   include(height_lock, As, Hs), exclude(height_lock, As, Ts),
        length(Hs, NH), length(Ts, NT),
        ( NH >= NT -> max_list(Hs, Lock) ; max_list(Ts, Lock) )
    ),
    ignore(Policy = _).

height_lock(A) :- A < 500000000.

add_test(Id, Loc, State, Policy, Sets, Names, Fs,
         test(Id, Doc, none, [comment(Loc)|Facts], [expects_changes(flip_spend, Changes)])) :-
    flip_doc(Doc),
    state_facts(State, Names, Fs, Facts),
    addition_sets(State, Sets, Policy, Changes0),
    maplist(change_strings(Names, add), Changes0, Changes).

%   The smallest sets of signatures and preimages whose addition meets the
%   policy, the delays and lock time staying as they are; [[]] when it is
%   already met, [] when more than three are needed (LE's flip bound).
addition_sets(State, Sets, Policy, Changes) :-
    (   holds_in(Policy, State)
    ->  Changes = [[]]
    ;   findall(Missing,
                ( member(S, Sets), locks_met(S, State),
                  missing(S, State, Missing) ),
                Ms0),
        sort(Ms0, Ms),
        (   Ms == [] -> Changes = []
        ;   maplist(length_key, Ms, LMs), keysort(LMs, [Min-_|_]),
            findall(M, member(Min-M, LMs), Mins),
            ( Min > 3 -> Changes = [] ; Changes = Mins )
        )
    ).


length_key(M, L-M) :- length(M, L).

locks_met(Set, s(_, _, Age, Secs, Lock)) :-
    forall(member(R, Set), lock_met(R, Age, Secs, Lock)).
lock_met(sig(_), _, _, _).
lock_met(preimage(_), _, _, _).
lock_met(older(N), Age, Secs, _) :- ms_older_blocks(N, B), ( integer(B) -> Age >= B ; B = seconds(S), Secs >= S ).
lock_met(after(N), _, _, L) :- ms_eval(after(N), attempt([], [], rel(0, 0), L)).

missing(Set, s(Sigs, Pres, _, _, _), Missing) :-
    findall(sig(K), ( member(sig(K), Set), \+ memberchk(K, Sigs) ), M1),
    findall(preimage(H), ( member(preimage(H), Set), \+ memberchk(H, Pres) ), M2),
    append(M1, M2, M0), msort(M0, Missing).

change_strings(Names, Kind, Set, Strings) :-
    maplist(change_string(Names, Kind), Set, Strings0),
    msort(Strings0, Strings).

change_string(Names, Kind, El, S) :-
    element_fact(El, Names, Fact),
    fact_sentence(Fact, Sent),
    format(string(S), "~w: ~w", [Kind, Sent]).

element_fact(sig(K), Names, sig(C)) :- name_of(Names, pk(K), C).
element_fact(preimage(H), Names, pre(C)) :- name_of(Names, hash(H), C).
element_fact(fact(F), _, F).

fact_sentence(sig(C), S) :- format(string(S), "the witness contains a signature by ~w", [C]).
fact_sentence(pre(C), S) :- format(string(S), "the witness reveals the preimage of ~w", [C]).
fact_sentence(confirmed(B), S) :- format(string(S), "the coin was confirmed in block ~w", [B]).
fact_sentence(spent_in(B), S) :- format(string(S), "the spending transaction is in block ~w", [B]).
fact_sentence(confirmed_at(T), S) :- format(string(S), "the coin was confirmed at the time ~w", [T]).
fact_sentence(spent_at(T), S) :- format(string(S), "the spending transaction is at the time ~w", [T]).
fact_sentence(locktime(L), S) :- format(string(S), "the spending transaction has the lock time ~w", [L]).

%   Key loss: every other key signs, every preimage is revealed, every
%   delay has passed. When the coin can still be spent, the flip
%   `it is not the case that the coin can be spent` lists the smallest sets
%   of facts whose removal would stop it — what the loss of that key leaves
%   indispensable; when it cannot, the key was indispensable itself.
keyloss_test(K, Later, Policy, Names, Fs, Test) :-
    ms_keys(Policy, Keys), delete(Keys, K, Others),
    ms_hashes(Policy, Hs), findall(H, member(hash(_, H), Hs), Pres),
    Later = s(_, _, Age, Secs, Lock),
    State = s(Others, Pres, Age, Secs, Lock),
    state_facts(State, Names, Fs, Facts),
    name_of(Names, pk(K), C),
    format(atom(Id), 'lost_~w', [C]),
    format(atom(Loc), 'the key of ~w lost, everything else given', [C]),
    flip_doc(Doc),
    (   holds_in(Policy, State)
    ->  removal_sets(Facts, Policy, Names, Sets),
        Test = test(Id, Doc, none, [comment(Loc)|Facts], [expects(spendable, [spendable]),
                                                       expects_changes(flip_block, Sets)])
    ;   Test = test(Id, Doc, none, [comment(Loc)|Facts], [expects(spendable, [])])
    ).

%   The smallest sets (at most 3) of the state's facts whose removal makes
%   the policy fail.
removal_sets(Facts, Policy, Names, Sets) :-
    between(1, 3, N),
    findall(Sub, ( subset_of_size(N, Facts, Sub), \+ holds_without(Sub, Facts, Policy, Names) ), Subs),
    Subs \== [], !,
    maplist(removal_strings, Subs, Sets0),
    sort(Sets0, Sets).
removal_sets(_, _, _, []).

removal_strings(Sub, Strings) :-
    maplist(removal_string, Sub, S0),
    msort(S0, Strings).

removal_string(F, S) :- fact_sentence(F, Sent), format(string(S), "remove: ~w", [Sent]).

subset_of_size(0, _, []) :- !.
subset_of_size(N, [X|Xs], [X|Ys]) :- N1 is N - 1, subset_of_size(N1, Xs, Ys).
subset_of_size(N, [_|Xs], Ys) :- length(Xs, L), L >= N, subset_of_size(N, Xs, Ys).

%   The policy on the facts that remain — a timelock whose fact is removed
%   is unknown, and so not met.
holds_without(Removed, Facts, Policy, Names) :-
    subtract(Facts, Removed, Left),
    facts_attempt(Left, Names, A),
    ms_eval(Policy, A).

facts_attempt(Facts, Names, attempt(Sigs, Pres, rel(Age, Secs), Lock)) :-
    findall(K, member(sig(K), Facts), SigC),
    findall(H, member(pre(H), Facts), PreC),
    findall(K0, ( member(C, SigC), member(pk(K0)-C, Names) ), Sigs),
    findall(H0, ( member(C, PreC), member(hash(H0)-C, Names) ), Pres),
    ( member(confirmed(B0), Facts), member(spent_in(B1), Facts) -> Age is B1 - B0 ; Age = none ),
    ( member(confirmed_at(T0), Facts), member(spent_at(T1), Facts) -> Secs is T1 - T0 ; Secs = none ),
    %  a lock time is met only once it is past: a transaction whose lock
    %  time is not below its block's height (or time) cannot be mined
    (   member(locktime(L), Facts), final(L, Facts) -> Lock = L ; Lock = none ).

final(L, Facts) :-
    (   L < 500000000 -> member(spent_in(M), Facts) ; member(spent_at(M), Facts) ),
    L < M, !.

		 /*******************************
		 *     QUERIES, VIEW, DOCS      *
		 *******************************/

queries(_, [query(spendable, spendable),
            query(flip_spend, flip(spendable)),
            query(flip_block, flip(not(spendable)))]).

%   The questions about the keys and hashes, when the program states them.
key_queries(KeyTemplates, Qs) :-
    findall(query(Q, Goal),
            ( member(template(F, _, _), KeyTemplates), key_query(F, Q, Goal) ), Qs).

key_query(public_key, keys, public_key(_, _)).
key_query(hash_function, hash_functions, hash_function(_, _)).
key_query(hash_value, hashes, hash_value(_, _)).

view(Title, Fs, view('custody explainer', Sentences)) :-
    format(string(TitleS), "the title is \"Who can spend this coin: ~w\".", [Title]),
    findall(S, ( member(F, Fs), view_fact(F, S) ), Witness),
    findall(S, ( member(F, Fs), view_lock(F, S) ), Locks0), list_to_set(Locks0, Locks),
    atomic_list_concat(Witness, ',\n        ', WT),
    format(string(WitnessS), "the facts about \"the witness\" are\n        ~w.", [WT]),
    (   Locks == []
    ->  LockSs = [], Keeps = []
    ;   atomic_list_concat(Locks, ',\n        ', LT),
        format(string(LockS), "the facts about \"the timelocks\" are\n        ~w.", [LT]),
        format(string(KeepS), "the flip keeps ~w.", [LT]),
        LockSs = [LockS], Keeps = [KeepS]
    ),
    append([[TitleS, "the case is a scenario, with the documents it is stated in.", WitnessS],
            LockSs,
            ["the result is whether the coin can be spent.",
             "the result shows its reasons.",
             "the result shows its citations.",
             "the result can be flipped, as \"What would let this coin be spent?\"."],
            Keeps], Sentences).

view_fact(sigs, "the witness contains a signature by a key").
view_fact(preimages, "the witness reveals the preimage of a hash").
view_lock(older_blocks, "the coin was confirmed in block a height").
view_lock(older_blocks, "the spending transaction is in block a height").
view_lock(older_time, "the coin was confirmed at the time a time").
view_lock(older_time, "the spending transaction is at the time a time").
view_lock(after_height, "the spending transaction is in block a height").
view_lock(after_height, "the spending transaction has the lock time a number").
view_lock(after_time, "the spending transaction is at the time a time").
view_lock(after_time, "the spending transaction has the lock time a number").

		 /*******************************
		 *           THE LEDGER         *
		 *******************************/

ledger(Tree, Policy, Paths, Names, _Fs, Opts, Ledger) :-
    option(notes(Notes), Opts, []),
    findall(E, ( member(pk(K)-C, Names), key_entry(K, C, Notes, E) ), KE),
    findall(E, ( member(hash(H)-C, Names), hash_entry(Policy, H, C, E) ), HE),
    findall(E, ( member(L-P, Paths), path_entry(L, P, Notes, E) ), PE),
    findall(E, lock_entry(Policy, Notes, E), LE0), list_to_set(LE0, LE),
    findall(E, thresh_entry(Policy, E), TE0), list_to_set(TE0, TE),
    fragment_entries(Tree, FE),
    Script = entry('the Script encoding', script, approximated,
                   'the twin is the spending policy (BIP 379, the semantics column), not the Script',
                   'the whole program',
                   'witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin'),
    ms_lock_warnings(Policy, Warnings),
    findall(entry(W, consensus, approximated, 'what the policy writes and consensus reads differ: the twin states what consensus reads', 'the rules', W),
            member(W, Warnings), WE),
    append([WE, KE, HE, PE, LE, TE, FE, [Script]], Ledger).

key_entry(K, C, Notes, entry(E, key, encoded, 'pk(key) -> the witness contains a signature by <role>', C, N)) :-
    format(string(E), "pk(~w)", [K]),
    ( memberchk(K-N0, Notes) -> N = N0 ; N = none ).

hash_entry(Policy, H, C, entry(E, hash, encoded, 'hash lock -> the witness reveals the preimage of <name>', C, none)) :-
    sub(Policy, hash(F, H)), !, format(string(E), "~w(~w)", [F, H]).

path_entry(L, P, Notes, entry(PT, 'spending path', V, 'a branch of the top-level or -> a rule concluding the coin can be spent', L, N)) :-
    ms_policy_text(P, PT),
    (   memberchk(L-N0, Notes) -> V = approximated, N = N0 ; V = encoded, N = none ).

lock_entry(Policy, Notes, entry(E, timelock, V, M, In, N)) :-
    sub(Policy, older(X)),
    format(string(E), "older(~w)", [X]),
    (   ms_older_blocks(X, B), integer(B)
    ->  M = 'older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction)',
        format(atom(In), 'the delay of ~w blocks', [B])
    ;   ms_older_blocks(X, seconds(S)),
        M = 'older(n) with the BIP 68 time flag -> the coin has been confirmed for N seconds and N >= 512 x (n and 0xffff)',
        format(atom(In), 'the delay of ~w seconds', [S])
    ),
    ( memberchk(older(X)-N0, Notes) -> V = approximated, N = N0 ; V = encoded, N = none ).
lock_entry(Policy, _, entry(E, timelock, encoded, M, In, none)) :-
    sub(Policy, after(X)),
    format(string(E), "after(~w)", [X]),
    (   X < 500000000 -> M = 'after(t) -> the lock time L is a block height and L >= t (lib/temporal)'
    ;   M = 'after(t) -> the lock time L is a time and L >= t (lib/temporal)'
    ),
    format(atom(In), 'the lock time ~w', [X]).

thresh_entry(Policy, entry(E, threshold, encoded, M, 'a count aggregate', none)) :-
    sub(Policy, thresh(K, Ps)),
    ms_policy_text(thresh(K, Ps), E),
    (   all_keys(Ps) -> M = 'thresh(k, keys) -> the count of the keys in the list that signed is at least k'
    ;   M = 'thresh(k, conditions) -> the count of the named conditions that are met is at least k'
    ).

%   The Miniscript fragments and wrappers of the source, each lifted by BIP
%   379's table.
fragment_entries(Tree, Entries) :-
    findall(F, tree_fragment(Tree, F), Fs0), sort(Fs0, Fs),
    findall(entry(F, fragment, encoded, M, 'the rules', none),
            ( member(F, Fs), fragment_mapping(F, M) ), Entries).

tree_fragment(f(F, Args), X) :- ( X = F ; member(A, Args), tree_fragment(A, X) ).
tree_fragment(w(Ws, E), X) :- ( member(W, Ws), atom_concat(W, ':', X) ; tree_fragment(E, X) ).
tree_fragment(p(W, E), X) :- ( format(atom(X), '~w@', [W]) ; tree_fragment(E, X) ).
tree_fragment(tree(Bs), X) :- ( X = '{...}' ; member(B, Bs), tree_fragment(B, X) ).

fragment_mapping(F, M) :- memberchk(F, [and_v, and_b, and_n]), !, M = 'X and Y (BIP 379) -> and'.
fragment_mapping(F, M) :- memberchk(F, [or_b, or_c, or_d, or_i]), !, M = 'X or Z (BIP 379) -> or'.
fragment_mapping(andor, 'andor(X,Y,Z) = (X and Y) or Z -> or of two branches').
fragment_mapping(F, M) :- memberchk(F, [multi, multi_a, sortedmulti]), !, M = 'multi(k, keys) -> thresh(k) of the keys'' signatures'.
fragment_mapping(F, M) :- memberchk(F, [pkh, pk_h, pk_k]), !, M = 'a key check -> a signature'.
fragment_mapping(wsh, 'the P2WSH wrapper: no effect on the policy').
fragment_mapping(sh, 'the P2SH wrapper: no effect on the policy').
fragment_mapping(tr, 'Taproot: the internal key''s signature, or any script leaf').
fragment_mapping('{...}', 'a Taproot script tree: any leaf').
fragment_mapping(F, 'a wrapper: no effect on the policy (BIP 379)') :- sub_atom(F, _, 1, 0, ':').
fragment_mapping(F, 'a branch probability: guides the compiler, no effect on who can spend') :- sub_atom(F, _, 1, 0, '@').

		 /*******************************
		 *           KEY LOSS           *
		 *******************************/

%!  key_loss(+Policy, +Names, -Rows) is det.
%
%   For the README: per key, can the coin still be spent without it (now,
%   after every delay).
key_loss(Policy, Names, Rows) :-
    ms_satisfactions(Policy, Sets),
    all_delays(Policy, Sets, s(_, _, Age, Secs, Lock)),
    ms_keys(Policy, Keys),
    ms_hashes(Policy, Hs), findall(H, member(hash(_, H), Hs), Pres),
    findall(row(C, Now, Later),
            ( member(K, Keys), name_of(Names, pk(K), C), delete(Keys, K, Others),
              ( ms_eval(Policy, attempt(Others, Pres, rel(0, 0), 0)) -> Now = yes ; Now = no ),
              ( ms_eval(Policy, attempt(Others, Pres, rel(Age, Secs), Lock)) -> Later = yes ; Later = no ) ),
            Rows).

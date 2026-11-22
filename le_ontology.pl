/*  le_ontology.pl — published ontologies as Prolog facts, fetched on demand

    A published ontology (WordNet first) is a large table of words and of
    "is a kind of" links. LE2 does not keep it in the repository. The first
    query that needs it downloads the published release once, converts it
    to Prolog facts, and keeps them in a cache folder:

      - the folder is $LE_ONTOLOGY_DIR, or else tmp/ontologies/ under the
        repository (tmp/ is not tracked by git);
      - the facts are compiled (a .qlf file beside the .pl), so that a later
        run loads them in about a second;
      - ontology_install/1 does the same ahead of time, for a server or a
        machine that is offline later:
            swipl -g "use_module(le_ontology), ontology_install(wordnet)" -t halt

    LE programs use an ontology through a thin layer of templates, the
    programs of examples/ontologies/ (docs/user/reference/language.md §14.6),
    with `prolog le_ontology:...` conditions. The predicates below only read
    the tables (and fetch a registered release, from a fixed address), so
    they are declared safe for the sandbox of `prolog` conditions.

    The ontologies (ontology_source/2):
      - wordnet: Open English WordNet 2025 (https://en-word.net), the
        maintained successor of Princeton WordNet, under the Creative Commons
        Attribution 4.0 licence. Its nouns are read: each sense (synset) with
        its words, its definition (gloss) and the senses it is a kind of
        (hypernyms and instance hypernyms).
*/
:- module(le_ontology, [
    ontology_source/2,          % ?Name, -Dict
    ontology_dir/1,             % -Dir
    ontology_install/1,         % +Name
    ontology_status/2,          % +Name, -Status
    ontology_convert/3,         % +Name, +Archive, +PlFile (tests: a local archive)
    ontology_use_cache/2,       % +Name, +Dir (tests: another cache)
    wordnet_ancestor/4,         % +Name, ?Ancestor, -Distance, -Sense
    wordnet_first_sense/3,      % +Name, +Class, -Sense
    wordnet_gloss/2,            % +Sense, -Gloss
    wordnet_words/2,            % +Sense, -Words
    wordnet_sense/3             % +Name, -Rank, -Sense
    ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(zip)).
:- use_module(library(readutil)).

:- dynamic loaded_ontology/1.
:- dynamic cache_dir_override/2.
:- dynamic ancestors_memo/2.

%!  ontology_source(?Name, -Source) is nondet.
%
%   The registered ontologies: title, home page, licence, the address of
%   the release, and the file name it is saved under in the cache.
ontology_source(wordnet, _{
    title: "Open English WordNet 2025",
    home: "https://en-word.net",
    licence: "Creative Commons Attribution 4.0 (CC-BY 4.0)",
    url: "https://github.com/globalwordnet/english-wordnet/releases/download/2025-edition/english-wordnet-2025.zip",
    archive: 'english-wordnet-2025.zip',
    facts: 'wordnet_2025.pl',
    module: le_ontology_wordnet
}).

% ------------------------------------------------------------------------
% The cache
% ------------------------------------------------------------------------

%!  ontology_dir(-Dir) is det.
%
%   The cache folder: $LE_ONTOLOGY_DIR, or tmp/ontologies under the
%   repository. Created when missing.
ontology_dir(Dir) :-
    (   getenv('LE_ONTOLOGY_DIR', D0), D0 \== ''
    ->  Dir = D0
    ;   module_property(le_ontology, file(F)),
        file_directory_name(F, Root),
        atomic_list_concat([Root, '/tmp/ontologies'], Dir)
    ),
    (   exists_directory(Dir) -> true
    ;   catch(make_directory_path(Dir), _, true)
    ).

ontology_cache(Name, Dir) :-
    (   cache_dir_override(Name, Dir) -> true ; ontology_dir(Dir) ).

%!  ontology_use_cache(+Name, +Dir) is det.
%
%   Use Dir as the cache of ontology Name (the tests use a small archive);
%   Dir = default goes back to ontology_dir/1. Forgets what was loaded.
ontology_use_cache(Name, Dir) :-
    with_mutex(le_ontology, (
        retractall(cache_dir_override(Name, _)),
        ( Dir == default -> true ; assertz(cache_dir_override(Name, Dir)) ),
        forget(Name) )).

forget(Name) :-
    retractall(loaded_ontology(Name)),
    retractall(ancestors_memo(_, _)),
    ontology_source(Name, S),
    M = S.module,
    forall(member(P, [wn_sense/3, wn_hyp/2, wn_lemma/2, wn_gloss/2, wn_exc/2]),
           ( P = F/A, functor(H, F, A), retractall(M:H) )).

%!  ontology_status(+Name, -Status) is det.
%
%   loaded, cached (converted, not loaded), downloaded (the release is
%   saved, not converted) or absent.
ontology_status(Name, Status) :-
    ontology_source(Name, S),
    ontology_cache(Name, Dir),
    directory_file_path(Dir, S.facts, Pl),
    directory_file_path(Dir, S.archive, Zip),
    (   loaded_ontology(Name) -> Status = loaded
    ;   exists_file(Pl) -> Status = cached
    ;   exists_file(Zip) -> Status = downloaded
    ;   Status = absent
    ).

%!  ontology_install(+Name) is det.
%
%   Download, convert and load ontology Name, unless done already.
ontology_install(Name) :-
    ensure(Name).

ensure(Name) :-
    loaded_ontology(Name), !.
ensure(Name) :-
    with_mutex(le_ontology, ensure_(Name)).

ensure_(Name) :-
    loaded_ontology(Name), !.
ensure_(Name) :-
    (   ontology_source(Name, S) -> true
    ;   domain_error(ontology, Name)
    ),
    ontology_cache(Name, Dir),
    directory_file_path(Dir, S.facts, Pl),
    directory_file_path(Dir, S.archive, Zip),
    (   exists_file(Pl) -> true
    ;   (   exists_file(Zip) -> true
        ;   download(Name, S.url, Zip)
        ),
        ontology_convert(Name, Zip, Pl)
    ),
    M = S.module,
    file_name_extension(Stem, pl, Pl),
    file_name_extension(Stem, qlf, Qlf),
    (   exists_file(Qlf), time_file(Qlf, TQ), time_file(Pl, TP), TQ >= TP
    ->  load_files(M:Qlf, [silent(true), if(true)])
    ;   catch(M:qcompile(Pl), _, load_files(M:Pl, [silent(true), if(true)]))
    ),
    assertz(loaded_ontology(Name)).

download(Name, URL, File) :-
    format(user_error, "le_ontology: downloading ~w from ~w~n", [Name, URL]),
    atom_concat(File, '.part', Part),
    catch(( use_module(library(http/http_open)),
            setup_call_cleanup(
                http_open(URL, In, [timeout(300)]),
                setup_call_cleanup(open(Part, write, Out, [type(binary)]),
                                   copy_stream_data(In, Out),
                                   close(Out)),
                close(In)),
            rename_file(Part, File) ),
          E,
          ( catch(delete_file(Part), _, true),
            message_text(E, Why),
            format(atom(Msg), "The ontology ~w could not be downloaded from ~w (~w). Install it on a machine with a connection: swipl -g \"use_module(le_ontology), ontology_install(~w)\" -t halt, then copy the file ~w.",
                   [Name, URL, Why, Name, File]),
            throw(error(le_ontology_unavailable(Name), context(le_ontology, Msg))) )).

message_text(E, Why) :-
    catch(message_to_codes(E, Why0), _, fail), !, Why = Why0.
message_text(E, Why) :-
    format(atom(Why), "~q", [E]).

message_to_codes(E, Text) :-
    message_to_codes(E, [], Codes), atom_codes(Text, Codes).
message_to_codes(E, _, Codes) :-
    '$messages':translate_message(E, Lines, []),
    with_output_to(codes(Codes), print_message_lines(current_output, '', Lines)).

% ------------------------------------------------------------------------
% Converting WordNet (the WordNet database files of the release)
% ------------------------------------------------------------------------

%!  ontology_convert(+Name, +Archive, +PlFile) is det.
%
%   Read the release Archive (a zip of the WordNet database files: data.noun,
%   index.noun, noun.exc in any folder; or a folder of these files) and
%   write the facts to PlFile:
%     wn_sense(Lemma, Rank, Sense)   Lemma lower case, words joined by _;
%                                    Rank 1 is the most frequent sense
%     wn_hyp(Sense, Super)           Sense is a kind (or an instance) of Super
%     wn_lemma(Sense, Lemma)         the words of the sense, lower case
%     wn_gloss(Sense, Gloss)         the definition, a string
%     wn_exc(Form, Lemma)            an irregular plural, from noun.exc
%   A sense is named as the release names it: 'oewn-03614484-n'.
ontology_convert(wordnet, Zip, Pl) :-
    format(user_error, "le_ontology: converting ~w~n", [Zip]),
    atom_concat(Pl, '.part', Part),
    setup_call_cleanup(
        open(Part, write, Out, [encoding(utf8)]),
        ( format(Out, "% Open English WordNet nouns, converted by le_ontology.pl from ~w~n", [Zip]),
          format(Out, "% Licence: Creative Commons Attribution 4.0 (https://en-word.net)~n", []),
          format(Out, ":- encoding(utf8).~n", []),
          format(Out, ":- discontiguous wn_lemma/2, wn_gloss/2, wn_hyp/2.~n", []),
          zip_member_lines(Zip, 'data.noun', data_line(Out)),
          zip_member_lines(Zip, 'index.noun', index_line(Out)),
          zip_member_lines(Zip, 'noun.exc', exc_line(Out)) ),
        close(Out)),
    rename_file(Part, Pl).

zip_member_lines(Dir, Base, Goal) :-
    exists_directory(Dir), !,
    directory_file_path(Dir, Base, File),
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       stream_lines(In, Goal),
                       close(In)).
zip_member_lines(Zip, Base, Goal) :-
    setup_call_cleanup(
        zip_open(Zip, read, Z, []),
        (   zip_member_named(Z, Base)
        ->  setup_call_cleanup(
                zipper_open_current(Z, In, [type(text), encoding(utf8)]),
                stream_lines(In, Goal),
                close(In))
        ;   existence_error(zip_member, Base)
        ),
        zip_close(Z)).

zip_member_named(Z, Base) :-
    zipper_goto(Z, first),
    zip_member_named_(Z, Base).
zip_member_named_(Z, Base) :-
    zipper_file_info(Z, Name, _),
    (   file_base_name(Name, Base) -> true
    ;   zipper_goto(Z, next), zip_member_named_(Z, Base)
    ).

stream_lines(In, Goal) :-
    read_line_to_string(In, L),
    (   L == end_of_file -> true
    ;   ( call(Goal, L) -> true ; true ),
        stream_lines(In, Goal)
    ).

% a line of data.noun: offset lex_filenum ss_type w_cnt (word lex_id)*
% p_cnt (pointer_symbol offset pos source/target)* | gloss
data_line(Out, L) :-
    sub_atom(L, 0, 1, _, C), char_type(C, digit),
    (   sub_string(L, B, _, A, " | ") -> sub_string(L, 0, B, _, Head), sub_string(L, _, A, 0, G0)
    ;   Head = L, G0 = ""
    ),
    split_string(G0, "", " ", [Gloss]),
    split_string(Head, " ", "", [Off, _Lex, _SsType, WC|Rest]),
    number_string_hex(WC, NW),
    take_words(NW, Rest, Words, [PC|Ptrs]),
    number_string(NP, PC),
    sense_id(Off, n, S),
    forall(member(W, Words), ( lemma_atom(W, LA), format(Out, "~q.~n", [wn_lemma(S, LA)]) )),
    format(Out, "~q.~n", [wn_gloss(S, Gloss)]),
    hypernyms(NP, Ptrs, S, Out).

number_string_hex(S, N) :- string_concat("0x", S, H), number_string(N, H).

take_words(0, Rest, [], Rest) :- !.
take_words(N, [W, _|Rest0], [W|Ws], Rest) :-
    N1 is N - 1, take_words(N1, Rest0, Ws, Rest).

hypernyms(0, _, _, _) :- !.
hypernyms(N, [Sym, Off, Pos, _|Rest], S, Out) :-
    (   memberchk(Sym, ["@", "@i"]), Pos == "n"
    ->  sense_id(Off, n, Super), format(Out, "~q.~n", [wn_hyp(S, Super)])
    ;   true
    ),
    N1 is N - 1, hypernyms(N1, Rest, S, Out).

sense_id(Off, Pos, S) :- format(atom(S), "oewn-~w-~w", [Off, Pos]).

% a word of a sense, as the release writes it ("Loafer", "carpet_slipper")
lemma_atom(W, LA) :- string_lower(W, L), atom_string(LA, L).

% a line of index.noun: lemma pos synset_cnt p_cnt (ptr)* sense_cnt
% tagsense_cnt (synset_offset){synset_cnt}
index_line(Out, L) :-
    \+ sub_string(L, 0, 1, _, " "),
    split_string(L, " ", "", Fs0), exclude(==(""), Fs0, Fs),
    Fs = [Lemma, _Pos, SC|_],
    number_string(NS, SC),
    length(Offs, NS), once(append(_, Offs, Fs)),
    atom_string(LA, Lemma),
    forall(nth1(R, Offs, Off), ( sense_id(Off, n, S), format(Out, "~q.~n", [wn_sense(LA, R, S)]) )).

exc_line(Out, L) :-
    split_string(L, " ", "", [Form, Lemma|_]),
    Lemma \== "",
    atom_string(FA, Form), atom_string(LA, Lemma),
    format(Out, "~q.~n", [wn_exc(FA, LA)]).

% ------------------------------------------------------------------------
% Reading WordNet
% ------------------------------------------------------------------------

wn(Goal) :-
    ensure(wordnet),
    ontology_source(wordnet, S), M = S.module,
    call(M:Goal).

%!  wordnet_ancestor(+Name, ?Ancestor, -Distance, -Sense) is nondet.
%
%   Name (a word or a phrase, in any case, plural or singular) has a noun
%   sense Sense that is a kind of a sense with the word Ancestor, Distance
%   "is a kind of" links up (0: a word of the same sense). Ancestor is a
%   string in lower case, its words separated by spaces ("athletic shoe").
%
%   A phrase that WordNet does not have is read by its last words, the
%   longest ending that WordNet has ("anti-theft chest bag" by "bag"): such
%   a phrase names a kind of what its ending names, one link further up.
%   For each Sense and Ancestor, the shortest distance.
wordnet_ancestor(Name, Ancestor, Distance, Sense) :-
    name_key(Name, Key),
    (   ancestors_memo(Key, Rows) -> true
    ;   ensure(wordnet),
        name_starts(Key, Starts),
        findall(A-D-S,
                ( member(S-E, Starts),
                  synset_ancestors(S, Pairs),
                  member(X-D0, Pairs),
                  D is D0 + E,
                  wn(wn_lemma(X, LA)),
                  lemma_text(LA, A) ),
                All),
        shortest(All, Rows),
        assertz(ancestors_memo(Key, Rows))
    ),
    (   nonvar(Ancestor) -> text_key(Ancestor, AK) ; true ),
    member(A-Distance-Sense, Rows),
    (   nonvar(Ancestor) -> AK == A ; Ancestor = A ).

text_key(T, K) :- text_to_string(T, S0), string_lower(S0, S1), normalize_space(string(K), S1).

% the shortest distance for each Ancestor-Sense
shortest(All, Rows) :-
    findall((A-S)-D, member(A-D-S, All), Keyed),
    keysort(Keyed, Sorted),
    group_pairs_by_key(Sorted, Groups),
    findall(A-D-S, ( member((A-S)-Ds, Groups), min_list(Ds, D) ), Rows0),
    % in the order of the senses' ranks, then by distance
    sort(2, @=<, Rows0, Rows).

%!  wordnet_first_sense(+Name, +Class, -Sense) is semidet.
%
%   The most frequent noun sense of Name that is a kind of a sense with the
%   word Class (the senses in the order of the release's index; for a
%   phrase read by its ending, the senses of the ending).
wordnet_first_sense(Name, Class, Sense) :-
    name_key(Name, Key),
    ensure(wordnet),
    name_starts(Key, Starts),
    member(Sense-_, Starts),
    once(wordnet_ancestor(Name, Class, _, Sense)), !.

%!  wordnet_sense(+Name, -Rank, -Sense) is nondet.
%
%   The noun senses of Name, the most frequent first (Rank 1).
wordnet_sense(Name, Rank, Sense) :-
    name_key(Name, Key),
    ensure(wordnet),
    lemma_forms(Key, Lemma),
    wn(wn_sense(Lemma, Rank, Sense)).

%!  wordnet_gloss(+Sense, -Gloss) is semidet.
wordnet_gloss(Sense, Gloss) :-
    text_to_atom(Sense, S),
    wn(wn_gloss(S, Gloss)).

%!  wordnet_words(+Sense, -Words) is semidet.
%
%   The words of a sense, as one string: "footwear, footgear".
wordnet_words(Sense, Words) :-
    text_to_atom(Sense, S),
    findall(T, ( wn(wn_lemma(S, LA)), lemma_text(LA, T) ), Ts),
    Ts \== [],
    atomic_list_concat(Ts, ', ', A), atom_string(A, Words).

text_to_atom(T, A) :- ( atom(T) -> A = T ; atom_string(A, T) ).

lemma_text(LA, T) :-
    atomic_list_concat(Ws, '_', LA), atomic_list_concat(Ws, ' ', A), atom_string(A, T).

% a name as WordNet writes a lemma: lower case, words joined by _
name_key(Name, Key) :-
    text_to_string(Name, S0), string_lower(S0, S1),
    split_string(S1, " \t\n_", " \t\n_\"'.,;:!?()", Ws0), exclude(==(""), Ws0, Ws),
    atomic_list_concat(Ws, '_', Key).

% the starting senses of a name, each with the links its reading adds: the
% senses of the whole name, or else of its longest ending that WordNet has
name_starts(Key, Starts) :-
    findall(S-0, ( lemma_forms(Key, L), wn(wn_sense(L, _, S)) ), Whole),
    (   Whole \== [] -> Starts0 = Whole
    ;   atomic_list_concat(Ws, '_', Key),
        ending_starts(Ws, Starts0)
    ),
    list_to_set(Starts0, Starts).

ending_starts([_|Ws], Starts) :-
    Ws \== [],
    atomic_list_concat(Ws, '_', K),
    findall(S-1, ( lemma_forms(K, L), wn(wn_sense(L, _, S)) ), Ss),
    (   Ss \== [] -> Starts = Ss
    ;   ending_starts(Ws, Starts)
    ), !.
ending_starts(_, []).

% the lemmas a form can be: itself, an irregular plural, or the regular
% plurals of English nouns (WordNet's "morphy" rules, on the last word)
lemma_forms(Key, L) :-
    findall(L0, lemma_form(Key, L0), Ls0), list_to_set(Ls0, Ls),
    member(L, Ls).

lemma_form(Key, Key).
lemma_form(Key, L) :- wn(wn_exc(Key, L)).
lemma_form(Key, L) :-
    member(Suf-Rep, [s-'', ses-s, xes-x, zes-z, ches-ch, shes-sh, men-man, ies-y]),
    atom_concat(Stem, Suf, Key), Stem \== '',
    atom_concat(Stem, Rep, L).

% every sense that S is a kind of, with its distance (0 for S): breadth
% first, so the first visit is the shortest
synset_ancestors(S, Pairs) :-
    bfs([S-0], [], Pairs).

bfs([], Seen, Seen).
bfs([X-D|Q], Seen, Out) :-
    (   memberchk(X-_, Seen)
    ->  bfs(Q, Seen, Out)
    ;   D1 is D + 1,
        findall(Y-D1, wn(wn_hyp(X, Y)), Ys),
        append(Q, Ys, Q1),
        bfs(Q1, [X-D|Seen], Out)
    ).

% ------------------------------------------------------------------------
% The sandbox of `prolog` conditions: these predicates read the tables,
% and fetch only a registered release from its fixed address.
% ------------------------------------------------------------------------

:- multifile sandbox:safe_primitive/1.
sandbox:safe_primitive(le_ontology:wordnet_ancestor(_, _, _, _)).
sandbox:safe_primitive(le_ontology:wordnet_first_sense(_, _, _)).
sandbox:safe_primitive(le_ontology:wordnet_gloss(_, _)).
sandbox:safe_primitive(le_ontology:wordnet_words(_, _)).
sandbox:safe_primitive(le_ontology:wordnet_sense(_, _, _)).
sandbox:safe_primitive(le_ontology:ontology_status(_, _)).

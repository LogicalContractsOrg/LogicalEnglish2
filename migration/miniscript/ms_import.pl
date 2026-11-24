/** <module> File ▸ Open of a Miniscript file: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls
    when the editor opens a file of Bitcoin spending policies. The file
    holds one policy, Miniscript expression or output descriptor per line:

        # A user and a co-signing service, the user alone after 90 days
        key_user = the user
        key_service = the cosigning service
        and(pk(key_user),or(99@pk(key_service),older(12960)))

    - a line starting with `#` is a comment; the comment just above a policy
      is its title;
    - `name = role` names a key or hash by its role (a legend line, for every
      policy of the file); a key without one is `key A`, `key B`, ...;
    - every other line is a policy.

    The first policy becomes the program opened (`<stem>.le`); each further
    one a program of its own beside it (`<stem>_2.le`, ...), the same
    translation build.pl makes for the catalogue (ms_twin.pl): one cited
    rule per spending path, the satisfaction analysis as scenarios, the
    key-loss flips and a view. The file itself is copied under sources/ and
    each rule quotes its line. A line that does not parse is kept in the
    first program as a TODO block, with the parser's complaint.
*/

:- module(ms_import, [import_miniscript/3, detect_miniscript/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(miniscript).
:- use_module(ms_twin).
:- use_module(le2(le_migration)).

%!  detect_miniscript(+Input) is semidet.
%
%   Input is a file in which at least one policy line parses.
detect_miniscript(Input) :-
    exists_file(Input),
    file_lines(Input, Lines),
    member(L, Lines), line_kind(L, policy(T)),
    catch(( ms_parse(T, Tree), compound_tree(Tree), ms_policy(Tree, _) ), _, fail), !.

%   A policy is a fragment (`pk(A)`, `wsh(...)`, `v:...`), not a bare word.
compound_tree(f(_, _)).
compound_tree(w(_, _)).
compound_tree(p(_, _)).

%!  import_miniscript(+Input, +OutDir, -Result) is det.
import_miniscript(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_lines(Input, Lines),
    file_base_name(Input, FileName),
    file_name_extension(Stem0, _, FileName),
    le_stem(Stem0, Stem),
    classify(Lines, Legend, Policies),
    partition(parsed, Policies, Good, Bad),
    (   Good == []
    ->  throw(error(format("no line of ~w is a Miniscript policy, Miniscript expression or descriptor", [FileName]), _))
    ;   true
    ),
    %  the file itself, cited
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([FileName, '.txt'], TextName),
    atomic_list_concat([SD, '/', TextName], TextCopy),
    copy_file(Input, TextCopy),
    atomic_list_concat(['sources/', TextName], TextRel),
    format(atom(Doc), 'the policy file ~w', [Stem]),
    copy_library(temporal, OutDir),
    length(Good, NG),
    numlist(1, NG, Is),
    maplist(twin_of(Stem, Legend, Doc, TextRel), Is, Good, Twins),
    Twins = [twin(Id1, _)|Others],
    foldl(write_twin(OutDir, Bad, Others), Twins, [], Reports0),
    reverse(Reports0, Reports),
    Reports = [report(LEFile, _, _, _)|_],
    maplist(report_note, Twins, Reports, Notes1),
    bad_notes(Bad, Notes2),
    (   Others == [] -> Notes3 = []
    ;   findall(N, member(twin(N, _), Others), ONs),
        atomic_list_concat(ONs, ', ', OT),
        format(string(N3), "The other policies of the file are programs of their own beside it: ~w.", [OT]),
        Notes3 = [N3]
    ),
    ignore(Id1 = _),
    findall(W, ( member(twin(_, TOpts), Twins), memberchk(policy(PT), TOpts),
                 catch(( miniscript:ms_text_policy(PT, TP), miniscript:ms_lock_warnings(TP, Ws) ), _, Ws = []),
                 member(W0, Ws), format(string(W), "WARNING: ~w.", [W0]) ), Notes4),
    append([Notes4, Notes1, Notes2, Notes3], Notes).

parsed(p(_, _, _, ok(_))).

report_note(twin(Id, _), report(_, Issues, counts(E, A, R), Fid), N) :-
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; the policy's own analysis: ~w tests pass, ~w fail, ~w errors.",
               [Id, E, A, R, NE, P, F, U])
    ;   format(string(N), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors.", [Id, E, A, R, NE])
    ).

bad_notes([], []) :- !.
bad_notes(Bad, [N]) :-
    length(Bad, K),
    format(string(N), "~w line(s) could not be read as a policy; each is a TODO block in the first program.", [K]).

		 /*******************************
		 *         THE FILE             *
		 *******************************/

file_lines(File, Lines) :-
    read_file_to_string(File, S, [encoding(utf8)]),
    split_string(S, "\n", "\r", Lines).

%   comment(Text) | legend(Name, Role) | policy(Text) | blank
line_kind(L0, K) :-
    normalize_space(string(L), L0),
    (   L == "" -> K = blank
    ;   sub_string(L, 0, 1, _, "#") -> sub_string(L, 1, _, 0, C0), normalize_space(string(C), C0), K = comment(C)
    ;   sub_string(L, B, 1, _, "="),
        sub_string(L, 0, B, _, N0), \+ sub_string(N0, _, _, _, "("),
        normalize_space(string(N), N0), N \== "",
        \+ sub_string(N, _, _, _, " "),
        B1 is B + 1, sub_string(L, B1, _, 0, R0), normalize_space(string(R), R0), R \== ""
    ->  K = legend(N, R)
    ;   K = policy(L)
    ).

%   The legend of the whole file, and each policy line with the comment
%   above it, its line number and whether it parses: p(Line, Title, Text,
%   ok(Tree) | error(Complaint)).
classify(Lines, Legend, Policies) :-
    length(Lines, N), numlist(1, N, Ns),
    pairs_keys_values(Ps, Ns, Lines),
    findall(Name-Role, ( member(_-L, Ps), line_kind(L, legend(NameS, RoleS)),
                         atom_string(Name, NameS), atom_string(Role, RoleS) ), Legend),
    classify_lines(Ps, none, Policies).

classify_lines([], _, []).
classify_lines([No-L|Ls], Title, Ps) :-
    line_kind(L, K),
    (   K = comment(C) -> classify_lines(Ls, C, Ps)
    ;   K = policy(T)
    ->  (   catch(( ms_parse(T, Tree), ms_policy(Tree, _) ), E, true)
        ->  (   nonvar(E) -> complaint(E, Msg), R = error(Msg)
            ;   compound_tree(Tree) -> R = ok(Tree)
            ;   R = error("a bare word or number, not a policy")
            )
        ;   R = error("the text does not parse")
        ),
        Ps = [p(No, Title, T, R)|Ps1],
        classify_lines(Ls, none, Ps1)
    ;   classify_lines(Ls, Title, Ps)
    ).

complaint(error(miniscript_syntax(_), _), "not the policy language, Miniscript or a descriptor (the parser stopped)") :- !.
complaint(error(miniscript_unsupported(T), _), M) :- !,
    format(string(M), "a fragment the translator does not lift: ~q", [T]).
complaint(E, M) :- format(string(M), "~q", [E]).

%   A program's name LE reads back.
le_stem(Stem0, Stem) :-
    downcase_atom(Stem0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum), C0 < 128 -> C = C0 ; C = 0'_ ), Cs0, Cs1),
    atom_codes(S1, Cs1), atomic_list_concat(Ps0, '_', S1), exclude(==(''), Ps0, Ps),
    (   Ps == [] -> Stem = policy
    ;   atomic_list_concat(Ps, '_', S2),
        ( sub_atom(S2, 0, 1, _, F), char_type(F, digit) -> atom_concat(p_, S2, Stem) ; Stem = S2 )
    ).

		 /*******************************
		 *          THE TWINS           *
		 *******************************/

twin_of(Stem, Legend, Doc, TextRel, I, p(No, Title0, Text, ok(_)), twin(Id, Opts)) :-
    ( I =:= 1 -> Id = Stem ; format(atom(Id), '~w_~w', [Stem, I]) ),
    (   Title0 == none -> format(string(Title), "Policy ~w of ~w (line ~w)", [I, Stem, No])
    ;   Title = Title0
    ),
    Opts = [title(Title), policy(Text), legend(Legend),
            source(Doc, none, TextRel, Text)].

%   Every twin into OutDir; the TODO blocks go into the first.
write_twin(OutDir, Bad, Others, twin(Id, Opts), Acc, [Report|Acc]) :-
    twin_migration(twin(Id, Opts), OutDir, M0),
    (   Acc == []                      % the first program
    ->  todo_items(Bad, Todos, TodoLedger),
        others_comment(Others, OC),
        M0 = migration(Meta, program(H, Items0), Ledger0, Tests),
        append([OC, Todos, Items0], Items),
        append(Ledger0, TodoLedger, Ledger),
        M = migration(Meta, program(H, Items), Ledger, Tests)
    ;   M = M0
    ),
    write_migration(M, OutDir, Id, Report).

others_comment([], []) :- !.
others_comment(Others, [comment(C)]) :-
    findall(N, member(twin(N, _), Others), Ns),
    atomic_list_concat(Ns, ', ', NT),
    format(string(C), "The file holds more policies; each is a program of its own beside this one: ~w.", [NT]).

todo_items(Bad, Items, Ledger) :-
    findall(residue(Id, [title(T), locator(Loc), note(Why), source(miniscript, Text)])-
            entry(Text, policy, residue, 'a line that is not a policy the translator reads', Id, Why),
            ( member(p(No, _, Text, error(Why)), Bad),
              format(atom(Id), 'line_~w', [No]),
              format(atom(Loc), 'line ~w of the file', [No]),
              format(atom(T), 'the policy on line ~w', [No]) ),
            Pairs),
    pairs_keys_values(Pairs, Items, Ledger).

/** <module> An s(CASP) (or Prolog) source file, read for its twin

    The front end of the s(CASP) -> Logical English translator (Phase 2c,
    the design notes roadmap.md §5.7): the file's terms with their line
    numbers and variable names, read with s(CASP)'s operators; the
    scenarios and queries LE1 wrote around its generated programs; and the
    LE1 metadata that is not program content.

    LE1 (the first Logical English, whose s(CASP) translations are the sCASP
    pack's test/le_programs) writes a scenario as a comment block

        /* Scenario alice
        is_born_in_on('John', the_UK, 1633737600.0).
        % */

    or, when the scenario is the one in force, as live clauses between
    `/* Scenario payment */` and `/* % */`; and its queries after
    `/** <examples> */` as `?- Goal.` terms. Its dates are Unix times
    (floats); its date arithmetic is `is_days_after/3`, which the programs
    call but do not define.
*/

:- module(scasp_source, [
    read_source/2              % +File, -source(Terms, Scenarios, Queries)
  ]).

%   A statement that is not s(CASP) (clingo's choice rules, disjunctive
%   heads, cardinality bounds, aggregates, ranges, weak constraints,
%   `#const`, ...) or does not read at all is kept in Terms as
%   '$not_scasp'(Kind, Text, Line) - [], Kind `clingo` (read, but only clingo means
%   it) or `unreadable`: the twin writes it as a residue block.

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

%!  read_source(+File, -Source) is det.
%
%   Source = source(Terms, Scenarios, Queries): Terms are Term-Bindings of
%   the program proper (LE1's metadata and the live scenario's facts left
%   out); Scenarios scenario(Name, Facts) in file order; Queries the `?-`
%   goals, each Goal-Bindings.
read_source(File, source(Program, Scenarios, Queries)) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    split_string(Text, "\n", "", Lines),
    scenario_blocks(Lines, 1, Blocks),
    read_positioned(File, Text, Terms),
    maplist(block_scenario, Blocks, Scenarios),
    findall(T1-Bs, ( member(t(T, Bs, L), Terms),
                     \+ in_live_block(L, Blocks),
                     \+ metadata(T),
                     \+ T = (?- _),
                     ( T = '$not_scasp'(K, X) -> T1 = '$not_scasp'(K, X, L) ; T1 = T ) ), Program),
    findall(G-Bs, member(t((?- G), Bs, _), Terms), Queries).

%   LE1's own facts and the loader's directives: not the program's content.
metadata(source_lang(_)).
metadata((:- module(_, _))).

		 /*******************************
		 *           SCENARIOS          *
		 *******************************/

%   block(Name, Live, FromLine, ToLine, FactLines)
scenario_blocks([], _, []).
scenario_blocks([L|Ls], N, Blocks) :-
    (   scenario_header(L, Name, Live)
    ->  N1 is N + 1,
        take_block(Ls, N1, Live, FactLines, Rest, End),
        Blocks = [block(Name, Live, N, End, FactLines)|Blocks1],
        End1 is End + 1,
        scenario_blocks(Rest, End1, Blocks1)
    ;   N1 is N + 1,
        scenario_blocks(Ls, N1, Blocks)
    ).

%   `/* Scenario alice` (a comment block) or `/* Scenario payment */` (live
%   clauses follow).
scenario_header(L0, Name, Live) :-
    normalize_space(string(L), L0),
    sub_string(L, 0, _, _, "/* Scenario "),
    sub_string(L, 12, _, 0, Rest0),
    (   sub_string(Rest0, B, _, 0, "*/") -> sub_string(Rest0, 0, B, _, Rest1), Live = true
    ;   Rest1 = Rest0, Live = false
    ),
    normalize_space(atom(Name0), Rest1),
    Name0 \== '',
    atomic_list_concat(Ws, ' ', Name0), atomic_list_concat(Ws, '_', Name).

take_block([], N, _, [], [], N).
take_block([L|Ls], N, Live, Facts, Rest, End) :-
    normalize_space(string(S), L),
    (   block_end(S)
    ->  Facts = [], Rest = Ls, End = N
    ;   Facts = [L|Facts1], N1 is N + 1,
        take_block(Ls, N1, Live, Facts1, Rest, End)
    ).

block_end(S) :- ( S == "% */" ; S == "/* % */" ; sub_string(S, _, _, 0, "% */") ), !.

in_live_block(Line, Blocks) :-
    member(block(_, true, From, To, _), Blocks), Line > From, Line < To, !.

block_scenario(block(Name, _, _, _, Lines), scenario(Name, Facts)) :-
    atomic_list_concat(Lines, '\n', Text),
    setup_call_cleanup(open_string(Text, In),
                       ( push_ops, read_all(In, Facts0) ),
                       close(In)),
    findall(F, ( member(F-_, Facts0), F \= (:- _) ), Facts).

read_all(In, Terms) :-
    catch(read_term(In, T, [variable_names(Bs), module(scasp_source_ops)]), _, T = end_of_file),
    (   T == end_of_file -> Terms = []
    ;   Terms = [T-Bs|Rest], read_all(In, Rest)
    ).

		 /*******************************
		 *     TERMS WITH THEIR LINES   *
		 *******************************/

read_positioned(File, Text, Terms) :-
    setup_call_cleanup(
        ( open(File, read, In, [encoding(utf8)]), push_ops ),
        read_positioned_terms(In, Text, Terms0),
        close(In)),
    weak_constraint_weights(Terms0, Terms).

read_positioned_terms(In, Text, Terms) :-
    stream_property(In, position(P0)), stream_position_data(char_count, P0, C0),
    catch(read_term(In, T, [variable_names(Bs), term_position(P), module(scasp_source_ops)]),
          E, T = '$syntax_error'(E)),
    (   T == end_of_file -> Terms = []
    ;   T = '$syntax_error'(_)
    ->  stream_property(In, position(P1)), stream_position_data(char_count, P1, C1),
        Len is C1 - C0, sub_string(Text, C0, Len, _, Chunk0),
        skip_layout(Chunk0, C0, Chunk, CS),
        (   Chunk == ""
        ->  Terms = Rest
        ;   line_of(Text, CS, Line),
            Terms = [t('$not_scasp'(unreadable, Chunk), [], Line)|Rest]
        ),
        read_positioned_terms(In, Text, Rest)
    ;   stream_position_data(line_count, P, Line),
        (   clingo_only(T)
        ->  stream_position_data(char_count, P, CS),
            stream_property(In, position(P1)), stream_position_data(char_count, P1, C1),
            Len is C1 - CS, sub_string(Text, CS, Len, _, Chunk1),
            split_string(Chunk1, "", " \t\r\n", [Chunk]),
            Terms = [t('$not_scasp'(clingo, Chunk), [], Line)|Rest]
        ;   Terms = [t(T, Bs, Line)|Rest]
        ),
        read_positioned_terms(In, Text, Rest)
    ).

%   Clauses that read as terms but only clingo gives a meaning: a choice
%   rule (`{a;b}.`, braces in a head or body) and a disjunctive head
%   (`a ; b.`, `a | b :- c.`).
clingo_only(T) :- T = (:- _), !, fail.
clingo_only(T) :- T = '#'(_), !, fail.
clingo_only(T) :- sub_term(S, T), nonvar(S), S = {}(_), !.
clingo_only(T) :- ( T = (H :- _) -> true ; T = H ), nonvar(H), ( H = (_ ; _) ; H = (_ '|' _) ), !.

%   Leading blanks and comments of a chunk that did not read.
skip_layout(S0, C0, S, C) :-
    string_codes(S0, Cs0), skip_layout_codes(Cs0, 0, Cs, K),
    string_codes(S1, Cs), split_string(S1, "", " \t\r\n", [S]),
    C is C0 + K.

skip_layout_codes([C|Cs], K0, Out, K) :- code_type(C, space), !, K1 is K0 + 1, skip_layout_codes(Cs, K1, Out, K).
skip_layout_codes([0'%|Cs], K0, Out, K) :- !,
    ( append(Com, [0'\n|Rest], Cs) -> length(Com, N), K1 is K0 + N + 2, skip_layout_codes(Rest, K1, Out, K) ; Out = [], K = K0 ).
skip_layout_codes([0'/, 0'*|Cs], K0, Out, K) :-
    append(Com, [0'*, 0'/|Rest], Cs), !,
    length(Com, N), K1 is K0 + N + 4, skip_layout_codes(Rest, K1, Out, K).
skip_layout_codes(Cs, K, Cs, K).

line_of(Text, C, Line) :-
    sub_string(Text, 0, C, _, Before),
    split_string(Before, "\n", "", Ls), length(Ls, Line).

%   clingo's weak constraint `:~ p. [1@1]` has no full stop after its
%   weight: the weight reads as the start of the next statement.
weak_constraint_weights([], []).
weak_constraint_weights([t('$not_scasp'(K1, W), [], L1), t('$not_scasp'(K2, S), [], L2)|Ts], Out) :-
    sub_string(W, 0, _, _, ":~"), sub_string(S, 0, _, _, "["),
    sub_string(S, B, 1, _, "]"), !,
    B1 is B + 1, sub_string(S, 0, B1, _, Weight), sub_string(S, B1, _, 0, Rest0),
    split_string(Rest0, "", " \t\r\n", [Rest]),
    format(string(W1), "~w ~w", [W, Weight]),
    (   Rest == ""
    ->  Out = [t('$not_scasp'(K1, W1), [], L1)|Out1], weak_constraint_weights(Ts, Out1)
    ;   Out = [t('$not_scasp'(K1, W1), [], L1)|Out1],
        sub_string(S, RB, _, _, Rest), sub_string(S, 0, RB, _, Skipped),
        split_string(Skipped, "\n", "", NLs), length(NLs, NL), L3 is L2 + NL - 1,
        weak_constraint_weights([t('$not_scasp'(K2, Rest), [], L3)|Ts], Out1)
    ).
weak_constraint_weights([T|Ts], [T|Out]) :- weak_constraint_weights(Ts, Out).

push_ops :-
    op(1150, fx, scasp_source_ops:(#)),
    op(1100, fx, scasp_source_ops:pred),
    op(1100, fx, scasp_source_ops:abducible),
    op(1100, fx, scasp_source_ops:show),
    op(1000, xfx, scasp_source_ops:(::)),
    op(900, fy, scasp_source_ops:not),
    forall(member(O, [#=, #<>, #<, #>, #=<, #>=]), op(700, xfx, scasp_source_ops:O)).

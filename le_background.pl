/** <module> The facts background: the knowledge used to read facts from a text

    A program can name a **facts background** (docs/user/reference/language.md
    §14.5):

        the facts background includes these resources:
            background/garments, background/presumptions.

    Each name is an ordinary Logical English program. The system never
    reasons with it: a query, a test, a view and an export of the program
    behave as if the section were not there. Only the reading step uses it
    ("Write it in English", the editor's assistant, the tools for other
    assistants) and the verifier's checks of the section.

    A background program has three kinds of templates:

      - **noted** templates: what a reader may write down from a text, close to
        the text's own words ("*a thing* is called *a name*", "the field *a
        field* of *a thing* reads *a value*"). They are the background's own
        scenario templates: marked `; undefined` (or `; judged`) there. When
        the background marks none, a noted template is one of its templates
        that it does not share with the main program, that no rule of it
        concludes and that has no fact in its knowledge base;
      - its own knowledge ("*a name* is a word for the kind *a kind*");
      - **shared** templates: templates of the main program, written in the
        same words, which its rules conclude. Only facts of the main program's
        scenario templates come back from the reading.

    The background step (apply_background/4) runs each background program on
    the facts the reader wrote, in the order in which the programs are named,
    each one also given the facts that the programs before it derived. Every
    fact of a shared template that a program proves, and that the text did
    not state, comes back with its origin, in the trailers of language.md
    §17.1:

        the fabric of item_505 is lightweight,
            according to customs presumptions, because "tshirt_fabric",
            confer "Men Tee Shirt".

    `according to` names the background program (the name of its knowledge
    base), `because` the rule, and `confer` the passage of the text that the
    noted fact under it quoted. The two readings, without and with
    presumptions, are then the source-scoped proof of §17.5 and need nothing
    here.

    When facts disagree (FactsBackground.md §3.5), the step applies one rule
    and makes one report, here and nowhere else (the reasoner never sees a
    background):

      - a stated fact beats a derived fact: for a template with one value (a
        template of `the functions are:`, in the main program or in the
        background), a derived fact with another value than the one the text
        states is not returned, and is shown as a note;
      - two background programs (or two rules) that give different values of
        a one-valued template give no fact, and a question for the reviewer.

    The values of a noted fact are compared in lower case: the step writes
    the quoted values of noted facts in lower case before it runs the
    backgrounds, so the background program writes its words in lower case.
*/

:- module(le_background, [
    facts_background/2,           % +KB, -Programs:list(bg)
    background_templates/3,       % +KB, -Noted:list(label), -Shared:list(F/A)
    apply_background/3,           % +KB, +Lines:list(string), -Result:dict
    background_issue/2,           % +KB, -Issue   (le_verifier)
    template_regex/2,             % +Label, -Regex
    line_fact_part/3              % +Line, -Fact, -Trailers
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pcre)).
:- use_module(library(yall)).
:- use_module(le_i18n).

% The name of the scenario that the reader's facts are put in, unlikely to
% clash with a scenario of the background program.
reading_scenario('nl__reading__').

% ------------------------------------------------------------------------
% The programs
% ------------------------------------------------------------------------

%!  facts_background(+KB, -Programs) is det.
%
%   The background programs that KB names, loaded, in the order in which
%   they are named. Each is bg(Name, Id, Start-End, Status): Name as
%   written, Id the resolved file or address, the range of the section in
%   the main program, and Status either loaded(BM, KBName, Text, Base) or
%   failed(Why).
facts_background(KB, Programs) :-
    (   current_predicate(KB:le_facts_background/4)
    ->  findall(bg(Name, Id, S-E, Status),
                ( KB:le_facts_background(Name, Id, S, E),
                  load_background(Id, Status) ),
                Programs)
    ;   Programs = []
    ).

load_background(Id, Status) :-
    (   catch(background_text(Id, Text, Base), Err, true)
    ->  (   nonvar(Err)
        ->  message_text(Err, Why), Status = failed(Why)
        ;   catch(le_kbs:load_text(Text, Base, BM, [skip_tests]), LErr, true),
            (   nonvar(LErr)
            ->  format(string(Why), "it does not load: ~w", [LErr]), Status = failed(Why)
            ;   \+ atom(BM)
            ->  Status = failed("it does not load")
            ;   current_predicate(BM:le_issue/6),
                BM:le_issue(error, _, Desc, _, _, _)
            ->  format(string(Why), "~w", [Desc]), Status = failed(Why)
            ;   (   le_kbs:program_kb_name(BM, KBName0) -> KBName = KBName0
                ;   file_base_name(Id, KBName0), file_name_extension(KBName, _, KBName0)
                ),
                Status = loaded(BM, KBName, Text, Base)
            )
        )
    ;   Status = failed("it cannot be read")
    ).

message_text(error(existence_error(_, What), _), Why) :- !,
    format(string(Why), "it cannot be found: ~w", [What]).
message_text(E, Why) :-
    format(string(Why), "~w", [E]).

background_text(Id, Text, Base) :-
    (   le_kbs:is_url(Id)
    ->  le_kbs:fetch_url(Id, Text),
        le_kbs:resource_base_of_url(Id, Base)
    ;   exists_file(Id)
    ->  read_file_to_string(Id, Text, []),
        file_directory_name(Id, Base)
    ;   throw(error(existence_error(file, Id), _))
    ).

% ------------------------------------------------------------------------
% The templates
% ------------------------------------------------------------------------

%!  background_templates(+KB, -Noted, -Shared) is det.
%
%   Noted: the labels of the noted templates of KB's background programs,
%   each n(Label, BM, F/A), for the reading to offer. Shared: the main
%   program's templates that some background concludes.
background_templates(KB, Noted, Shared) :-
    facts_background(KB, Programs),
    findall(n(Label, BM, F/A),
            ( member(bg(_, _, _, loaded(BM, _, _, _)), Programs),
              noted_template(KB, BM, F, A),
              bg_label(BM, F, A, Label) ),
            Noted0),
    dedup_noted(Noted0, Noted),
    findall(F/A, ( member(bg(_, _, _, loaded(BM, _, _, _)), Programs),
                   shared_template(KB, BM, F, A) ), Shared0),
    sort(Shared0, Shared).

dedup_noted([], []).
dedup_noted([n(L, B, FA)|Ns], [n(L, B, FA)|Rest]) :-
    exclude([n(L2, _, _)]>>(L2 == L), Ns, Ns1),
    dedup_noted(Ns1, Rest).

% a template of the main program that the background also declares, and
% concludes (by a rule or a fact of its knowledge base)
shared_template(KB, BM, F, A) :-
    bg_template(BM, F, A, _),
    main_template(KB, F, A),
    concluded(BM, F, A).

main_template(KB, F, A) :-
    le_kbs:template_of(KB, F, A, _, _), !.

bg_template(BM, F, A, Unknown) :-
    le_kbs:template_of(BM, F, A, Dict, _),
    \+ sub_atom(F, 0, _, _, le_),
    ( Dict = dict(_, _, _, _, _, _, Unknown0) -> Unknown = Unknown0 ; Unknown = none ).

% the main program's scenario templates: the ones it marks `; undefined` or
% `; judged`; when it marks none, the ones its rules do not conclude
main_scenario_template(KB, F, A) :-
    (   once(( le_kbs:template_of(KB, _, _, D0, _), D0 = dict(_, _, _, _, _, _, U0),
               scenario_mark(U0) ))
    ->  le_kbs:template_of(KB, F, A, D, _), D = dict(_, _, _, _, _, _, U), scenario_mark(U)
    ;   le_kbs:template_of(KB, F, A, _, _), \+ concluded_by_rule(KB, F, A)
    ).

scenario_mark(U) :- nonvar(U), memberchk(U, [undefined, judged, scenario_element]).

concluded(BM, F, A) :-
    functor(H, F, A),
    current_predicate(BM:F/A),
    catch(clause(BM:H, _), _, fail), !.

concluded_by_rule(M, F, A) :-
    functor(H, F, A),
    current_predicate(M:F/A),
    le_kbs:kb_own_predicate(M, H),
    catch(( clause(M:H, B), B \== true ), _, fail), !.

noted_template(KB, BM, F, A) :-
    (   once(( bg_template(BM, F0, A0, U0), scenario_mark(U0), \+ main_template(KB, F0, A0) ))
    ->  bg_template(BM, F, A, U), scenario_mark(U), \+ main_template(KB, F, A)
    ;   bg_template(BM, F, A, _),
        \+ main_template(KB, F, A),
        \+ concluded(BM, F, A)
    ).

% the label of a template, its places written *a type*
bg_label(M, F, A, Label) :-
    le_kbs:template_of(M, F, A, Dict, _),
    arg(2, Dict, NTs), arg(3, Dict, WV),
    copy_term(NTs-WV, NTsC-WVC),
    maplist([V-Type]>>( atom(Type)
                       -> ( sub_atom(Type, 0, 1, _, C), memberchk(C, [a, e, i, o, u]) -> Art = an ; Art = a ),
                          format(atom(V), "*~w ~w*", [Art, Type])
                       ;  V = '*a thing*' ), NTsC),
    le_kbs:canonical_string(WVC, Label0),
    re_replace("(\\w) - (\\w)"/g, "$1-$2", Label0, Label), !.

% ------------------------------------------------------------------------
% Lines of facts, read by their words
% ------------------------------------------------------------------------

%!  template_regex(+Label, -Regex) is semidet.
%
%   The regular expression of a template label: its words, white space
%   between them free, each *placeholder* a group.
template_regex(Label, Re) :-
    re_split("\\*[^*]+\\*", Label, Parts),
    Parts = [_, _|_],
    template_regex_parts(Parts, 1, Pieces),
    atomic_list_concat(Pieces, Body),
    format(string(Re), "^\\s*~w\\s*\\.?\\s*$", [Body]).

template_regex_parts([], _, []).
template_regex_parts([P|Ps], I, [Q|Qs]) :-
    (   I mod 2 =:= 1
    ->  normalize_space(string(P1), P),
        string_chars(P1, Cs),
        foldl([C, A0, A]>>( C == ' ' -> string_concat(A0, "\\s+", A)
                          ; sub_atom('.?*+^$()[]{}|\\/-', _, _, _, C) -> format(string(A), "~w\\~w", [A0, C])
                          ; string_concat(A0, C, A) ), Cs, "", P3),
        (   P3 == "" -> Q = "\\s*"
        ;   I == 1 -> format(string(Q), "~w\\s+", [P3])
        ;   Ps == [] -> format(string(Q), "\\s+~w", [P3])
        ;   format(string(Q), "\\s+~w\\s+", [P3])
        )
    ;   Q = "(.+?)"
    ),
    I1 is I + 1,
    template_regex_parts(Ps, I1, Qs).

%!  line_fact_part(+Line, -Fact, -Trailers) is det.
%
%   A line of facts cut before its first provenance trailer (", according
%   to", ", as stated in", ", because", ", confer").
line_fact_part(Line, Fact, Rest) :-
    findall(K, ( member(Key, [confer, according_to, as_stated_in, because]),
                 le_i18n:kw_synonym_words(Key, Ws),
                 atomic_list_concat(Ws, ' ', K0),
                 format(string(K), ", ~w ", [K0]) ), Keys),
    (   findall(B, ( member(K, Keys), sub_string(Line, B, _, _, K) ), Bs), Bs \== []
    ->  min_list(Bs, Cut),
        sub_string(Line, 0, Cut, _, Fact), sub_string(Line, Cut, _, 0, Rest)
    ;   Fact = Line, Rest = ""
    ).

% the passage that a line quotes (its confer trailer), or ""
line_passage(Line, Passage) :-
    le_i18n:kw_synonym_words(confer, Ws), atomic_list_concat(Ws, ' ', K),
    format(string(Re), "~w\\s+\"([^\"]*)\"", [K]),
    (   re_matchsub(Re, Line, Sub, [])
    ->  get_dict(1, Sub, Passage)
    ;   Passage = ""
    ).

% the line is an instance of one of the labels
line_matches(Res, Line) :-
    line_fact_part(Line, Fact, _),
    member(Re, Res),
    catch(re_match(Re/i, Fact), _, fail), !.

% the quoted values of the fact part of a line, in lower case
lower_quoted(Line0, Line) :-
    line_fact_part(Line0, Fact0, Rest),
    split_string(Fact0, "\"", "", Parts0),
    lower_parts(Parts0, out, Parts),
    atomic_list_concat(Parts, "\"", Fact),
    string_concat(Fact, Rest, Line).

lower_parts([], _, []).
lower_parts([P0|Ps0], Where, [P|Ps]) :-
    ( Where == in -> string_lower(P0, P), Next = out ; P = P0, Next = in ),
    lower_parts(Ps0, Next, Ps).

% ------------------------------------------------------------------------
% The background step
% ------------------------------------------------------------------------

%!  apply_background(+KB, +Lines, -Result) is det.
%
%   Lines: the facts the reader wrote (strings, one fact each, with their
%   trailers). Result is a dict:
%
%     - lines: the facts to put in the scenario: the reader's facts of the
%       main program, as they were written, then the derived facts with their
%       trailers. Noted facts are left out;
%     - derived: one dict per derived fact: fact, line, program, rule,
%       passage, from (the reader's lines it rests on);
%     - noted: the reader's noted facts, each with what it produced;
%     - unused: the noted facts that produced nothing (a word that no rule
%       of the background knows);
%     - notes: a derived fact left out because the text states otherwise;
%     - questions: two values of a one-valued template that the background
%       programs gave, for a person to decide;
%     - programs: the background programs, each with its status.
%
%   Without a background program, Lines come back as they are.
apply_background(KB, Lines0, Result) :-
    facts_background(KB, Programs),
    exclude([L]>>( split_string(L, "", " \t\r\n", [""]) ), Lines0, Lines1),
    maplist([L0, L]>>( split_string(L0, "", " \t\r\n", [L]) ), Lines1, Lines2),
    % which lines are noted facts
    findall(Re, ( member(bg(_, _, _, loaded(BM, _, _, _)), Programs),
                  noted_template(KB, BM, F, A),
                  bg_label(BM, F, A, Label),
                  template_regex(Label, Re) ), NotedRes),
    maplist(classify_line(NotedRes), Lines2, Classified),
    findall(L, member(main(L), Classified), MainLines),
    findall(L, member(noted(L), Classified), NotedLines),
    % the reader's lines as the backgrounds read them
    findall(L, ( member(C, Classified), ( C = main(L) ; C = noted(L0), lower_quoted(L0, L) ) ), Given),
    run_programs(KB, Programs, Given, [], Derived0),
    resolve_conflicts(KB, Programs, Given, Derived0, Derived, Notes, Questions),
    findall(DL, member(d(_, _, DL, _, _, _, _), Derived), DerivedLines),
    append(MainLines, DerivedLines, OutLines),
    findall(_{fact: FT, line: DL, program: P, rule: R, passage: Pa, from: Fr},
            member(d(_, FT, DL, P, R, Pa, Fr), Derived), DerivedJSON),
    findall(_{fact: NL, produced: Prod},
            ( member(NL0, NotedLines), lower_quoted(NL0, NL),
              findall(FT, ( member(d(_, FT, _, _, _, _, Fr), Derived0), memberchk(NL, Fr) ), Prod0),
              sort(Prod0, Prod) ),
            NotedJSON),
    findall(N, ( member(N0, NotedJSON), N0.produced == [] , N = N0.fact ), Unused),
    findall(_{name: Name, program: PName, status: St},
            ( member(bg(Name, _, _, Status), Programs),
              (   Status = loaded(_, PName, _, _) -> St = "loaded"
              ;   Status = failed(Why), PName = Name, St = Why
              ) ),
            ProgramsJSON),
    Result = _{lines: OutLines, derived: DerivedJSON, noted: NotedJSON,
               unused: Unused, notes: Notes, questions: Questions,
               programs: ProgramsJSON}.

classify_line(NotedRes, Line, Class) :-
    (   NotedRes \== [], line_matches(NotedRes, Line)
    ->  Class = noted(Line)
    ;   Class = main(Line)
    ).

% Each program in turn, on the reader's facts and the facts derived so far.
run_programs(_, [], _, Derived, Derived).
run_programs(KB, [bg(_, _, _, Status)|Ps], Given, Derived0, Derived) :-
    (   Status = loaded(BM, KBName, Text, Base)
    ->  findall(DL, member(d(_, _, DL, _, _, _, _), Derived0), Fed),
        append(Given, Fed, Input),
        catch(run_program(KB, BM, KBName, Text, Base, Input, Derived0, New0), E,
              ( print_message(warning, format("The facts background ~w failed: ~q", [KBName, E])),
                New0 = [] )),
        maplist(through_fed(Derived0), New0, New),
        append(Derived0, New, Derived1)
    ;   Derived1 = Derived0
    ),
    run_programs(KB, Ps, Given, Derived1, Derived).

% A fact derived from a fact that an earlier program derived rests on the
% reader's lines under that fact, and quotes their passage.
through_fed(Before, d(K, FT, DL0, P, R, Pa0, From0), d(K, FT, DL, P, R, Pa, From)) :-
    findall(L, ( member(L0, From0),
                 (   member(d(_, _, L0, _, _, _, F0), Before) -> member(L, F0)
                 ;   L = L0
                 ) ),
            From1),
    list_to_set(From1, From),
    (   Pa0 == "", from_passage(From, Pa1), Pa1 \== ""
    ->  Pa = Pa1, derived_line(FT, P, R, Pa, DL)
    ;   Pa = Pa0, DL = DL0
    ).

%   run_program(+KB, +BM, +Name, +Text, +Base, +Input, +Before, -New)
%
%   The background's text with one more scenario, the Input lines; each
%   shared template asked for every answer with no assumption. An answer
%   proved by a fact of that scenario is stated (or fed), not derived. A
%   derived answer is d(Key, FactText, Line, Program, Rule, Passage, From):
%   Key = F/A-Head; From the input lines its proof rests on.
run_program(KB, BM, KBName, Text, Base, Input, Before, New) :-
    reading_scenario(SN),
    string_length(Text, L0),
    format(string(Header), "\n\nscenario ~w is:\n", [SN]),
    string_length(Header, LH),
    ScStart is L0 + LH,
    foldl([Line, O0-Acc0, O-[r(O0, O1, Line)|Acc0]]>>(
              string_length(Line, LL), O1 is O0 + 4 + LL, O is O1 + 1 ),
          Input, ScStart-[], _-RangesRev),
    reverse(RangesRev, Ranges),
    findall(S, ( member(Line, Input), format(string(S), "    ~w", [Line]) ), Indented),
    atomic_list_concat(Indented, "\n", Body),
    atomic_list_concat([Text, Header, Body, "\n"], Full),
    le_kbs:load_text(Full, Base, RM, [skip_tests]),
    findall(F/A, shared_template(KB, BM, F, A), Shared0), sort(Shared0, Shared),
    le_kbs:createSession(RM, SM),
    call_cleanup(
        ( le_kbs:setScenarion(SM, SN),
          findall(d(F/A-Head, FT, DL, KBName, Rule, Passage, From),
                  ( member(F/A, Shared),
                    main_scenario_template(KB, F, A),
                    functor(Head, F, A),
                    catch(le_kbs:query(SM, Head, _, [], Why), _, fail),
                    ground(Head),
                    \+ stated_by(Why, Ranges, ScStart),
                    \+ memberchk(d(F/A-Head, _, _, _, _, _, _), Before),
                    proof_rule(RM, Why, Rule),
                    proof_lines(Why, Ranges, ScStart, From),
                    from_passage(From, Passage),
                    fact_text(RM, Head, FT),
                    derived_line(FT, KBName, Rule, Passage, DL) ),
                  New0) ),
        le_kbs:destroySession(SM)),
    dedup_derived(New0, New).

dedup_derived([], []).
dedup_derived([D|Ds], [D|Rest]) :-
    D = d(Key, _, _, _, _, _, _),
    exclude([d(K2, _, _, _, _, _, _)]>>(K2 =@= Key), Ds, Ds1),
    dedup_derived(Ds1, Rest).

% the top of the proof is a fact of the reading scenario
stated_by([success(_, range(S, _), _, _)|_], _, ScStart) :- integer(S), S >= ScStart, !.
stated_by(success(_, range(S, _), _, _), _, ScStart) :- integer(S), S >= ScStart.

% the label of the rule that concluded the answer
proof_rule(RM, Why, Rule) :-
    ( Why = [Top|_] -> true ; Top = Why ),
    Top = success(_, range(S, E), _, _),
    (   current_predicate(RM:le_source_info/4),
        RM:le_source_info(_, S, E, ID), ID \== main
    ->  format(string(Rule), "~w", [ID])
    ;   format(string(Rule), "the rule at ~w", [S])
    ), !.
proof_rule(_, _, "").

% the input lines whose facts the proof used
proof_lines(Why, Ranges, ScStart, From) :-
    findall(Line, ( sub_success(Why, S),
                    integer(S), S >= ScStart,
                    member(r(LS, LE, Line), Ranges), S >= LS, S =< LE ), From0),
    list_to_set(From0, From).

sub_success(L, S) :- is_list(L), !, member(X, L), sub_success(X, S).
sub_success(success(_, range(S0, _), _, Cs), S) :- !,
    ( S = S0 ; sub_success(Cs, S) ).
sub_success(T, S) :- compound(T), arg(_, T, A), compound(A), sub_success(A, S).

from_passage(From, Passage) :-
    (   member(L, From), line_passage(L, Passage), Passage \== "" -> true
    ;   Passage = ""
    ).

% a fact in the words of its template, its text values quoted
fact_text(RM, Head, Text) :-
    le_kbs:item_to_instance(RM, Head, Tokens),
    maplist([T, Q]>>( string(T) -> format(string(Q), "\"~w\"", [T]) ; Q = T ), Tokens, Quoted),
    le_kbs:canonical_string(Quoted, Text).

derived_line(FT, KBName, Rule, Passage, Line) :-
    kw_text(according_to, Acc), kw_text(because, Bec), kw_text(confer, Conf),
    (   Passage == ""
    ->  format(string(Line), "~w, ~w ~w, ~w \"~w\".", [FT, Acc, KBName, Bec, Rule])
    ;   format(string(Line), "~w, ~w ~w, ~w \"~w\", ~w \"~w\".", [FT, Acc, KBName, Bec, Rule, Conf, Passage])
    ).

kw_text(Key, Text) :-
    le_i18n:kw_synonym_words(Key, Ws), !,
    atomic_list_concat(Ws, ' ', Text).

% ------------------------------------------------------------------------
% When facts disagree (FactsBackground.md §3.5)
% ------------------------------------------------------------------------

resolve_conflicts(KB, Programs, Given, Derived0, Derived, Notes, Questions) :-
    stated_facts(KB, Programs, Given, Stated),
    % 1. the text states another value of a one-valued template
    beaten(Derived0, KB, Programs, Stated, Beaten, Derived1),
    findall(Note, ( member(d(F/A-H, FT, _, P, R, _, _), Beaten),
                    member(F/A-S, Stated), same_subject(H, S),
                    stated_text(Programs, S, ST),
                    format(string(Note), "The text states that ~w; ~w (rule ~w) would give that ~w.", [ST, P, R, FT]) ),
            Notes0),
    sort(Notes0, Notes),
    % 2. two derived values of a one-valued template
    findall(D, ( member(D, Derived1), D = d(F/A-H, _, _, _, _, _, _),
                 one_valued(KB, Programs, F, A),
                 member(d(F/A-H2, _, _, _, _, _, _), Derived1),
                 same_subject(H, H2), H \=@= H2 ), Clashing0),
    list_to_set(Clashing0, Clashing),
    subtract(Derived1, Clashing, Derived),
    findall(Q, ( member(d(F/A-H, FT, _, P, R, _, _), Clashing),
                 member(d(F/A-H2, FT2, _, P2, R2, _, _), Clashing),
                 same_subject(H, H2), H @< H2,
                 format(string(Q), "~w (rule ~w) gives that ~w, but ~w (rule ~w) gives that ~w. Which is right?",
                        [P, R, FT, P2, R2, FT2]) ),
             Questions0),
    sort(Questions0, Questions).

beaten([], _, _, _, [], []).
beaten([D|Ds], KB, Programs, Stated, Beaten, Kept) :-
    D = d(F/A-H, _, _, _, _, _, _),
    (   one_valued(KB, Programs, F, A),
        member(F/A-S, Stated), same_subject(H, S), H \=@= S
    ->  Beaten = [D|Beaten1], Kept = Kept1
    ;   Beaten = Beaten1, Kept = [D|Kept1]
    ),
    beaten(Ds, KB, Programs, Stated, Beaten1, Kept1).

% the same template and the same thing: every place but the last is equal
same_subject(H1, H2) :-
    H1 =.. [F|A1], H2 =.. [F|A2],
    append(S1, [_], A1), append(S2, [_], A2),
    S1 == S2.

% a template with one value: declared in `the functions are:` by the main
% program or by a background program
one_valued(KB, Programs, F, A) :-
    (   declared_function(KB, F/A)
    ;   member(bg(_, _, _, loaded(BM, _, _, _)), Programs),
        declared_function(BM, F/A)
    ), !.

declared_function(M, FA) :-
    current_predicate(M:le_function/1),
    M:le_function(FA).

% the facts of shared templates that the reader stated, as the first
% program that declares their template reads them
stated_facts(KB, Programs, Given, Stated) :-
    findall(F/A-H,
            ( member(bg(_, _, _, loaded(BM, _, Text, Base)), Programs),
              given_terms(BM, Text, Base, Given, Terms),
              member(H, Terms),
              functor(H, F, A), shared_template(KB, BM, F, A) ),
            Stated0),
    sort(Stated0, Stated).

given_terms(_BM, Text, Base, Given, Terms) :-
    reading_scenario(SN),
    findall(S, ( member(Line, Given), format(string(S), "    ~w", [Line]) ), Indented),
    atomic_list_concat(Indented, "\n", Body),
    format(string(Full), "~w\n\nscenario ~w is:\n~w\n", [Text, SN, Body]),
    catch(le_kbs:load_text(Full, Base, RM, [skip_tests]), _, fail),
    catch(RM:scenario(SN, Ts), _, fail), !,
    findall(H, ( member(fact_with_source(H0, _, _), Ts),
                 ( H0 = (H :- _) -> true ; H = H0 ), compound(H), ground(H) ), Terms).
given_terms(_, _, _, _, []).

stated_text(Programs, S, Text) :-
    (   member(bg(_, _, _, loaded(BM, _, _, _)), Programs),
        catch(fact_text(BM, S, Text), _, fail)
    ->  true
    ;   term_string(S, Text)
    ).

% ------------------------------------------------------------------------
% The verifier's checks (FactsBackground.md §3.6)
% ------------------------------------------------------------------------

%!  background_issue(+KB, -Issue) is nondet.
%
%   issue(Type, Description, Fix, Start, End), located on the line of the
%   section `the facts background includes these resources:`.
background_issue(KB, Issue) :-
    current_predicate(KB:le_facts_background/4),
    once(KB:le_facts_background(_, _, _, _)),
    facts_background(KB, Programs),
    member(bg(Name, _, S-E, Status), Programs),
    background_program_issue(KB, Name, Status, S, E, Issue).

background_program_issue(_, Name, failed(Why), S, E, issue(background_missing, D, F, S, E)) :-
    le_msg(background_missing_desc, [name-Name, why-Why], D),
    le_msg(background_missing_fix, [], F).
background_program_issue(KB, _, loaded(BM, P, _, _), S, E, Issue) :-
    loaded_issue(KB, BM, P, S, E, Issue).

% a background rule concludes what the main rules conclude
loaded_issue(KB, BM, P, S, E, issue(background_decides, D, F, S, E)) :-
    bg_template(BM, Fn, A, _),
    main_template(KB, Fn, A),
    concluded(BM, Fn, A),
    concluded_by_rule(KB, Fn, A),
    \+ main_scenario_template(KB, Fn, A),
    bg_label(BM, Fn, A, Label),
    le_msg(background_decides_desc, [program-P, template-Label], D),
    le_msg(background_decides_fix, [], F).
% a value that no main rule reads
loaded_issue(KB, BM, P, S, E, issue(background_unread_value, D, F, S, E)) :-
    findall(Fn/A, shared_template(KB, BM, Fn, A), FAs0), sort(FAs0, FAs),
    member(Fn/A, FAs),
    functor(H, Fn, A),
    findall(I-V, ( catch(clause(BM:H, _), _, fail), arg(I, H, V), atom(V) ), IVs0),
    sort(IVs0, IVs),
    member(I-V, IVs),
    catch(le_verifier:with_rule_index(KB, le_verifier:slot_values(KB, Fn, A, I, Values)), _, fail),
    Values \== [], \+ memberchk(V, Values),
    \+ catch(le_verifier:with_rule_index(KB, le_verifier:slot_open(KB, Fn, A, I)), _, fail),
    bg_label(BM, Fn, A, Label),
    le_verifier:shown_values(Values, Shown),
    le_msg(background_unread_value_desc, [program-P, value-V, template-Label, values-Shown], D),
    le_msg(background_unread_value_fix, [], F).
% a noted template that no background rule reads
loaded_issue(KB, BM, P, S, E, issue(background_unused_noted, D, F, S, E)) :-
    noted_template(KB, BM, Fn, A),
    \+ catch(le_verifier:read_by_a_rule(BM, Fn, A), _, fail),
    bg_label(BM, Fn, A, Label),
    le_msg(background_unused_noted_desc, [program-P, template-Label], D),
    le_msg(background_unused_noted_fix, [], F).
% nothing shared
loaded_issue(KB, BM, P, S, E, issue(background_shares_nothing, D, F, S, E)) :-
    \+ shared_template(KB, BM, _, _),
    le_msg(background_shares_nothing_desc, [program-P], D),
    le_msg(background_shares_nothing_fix, [], F).
% a rule with no source
loaded_issue(_KB, BM, P, S, E, issue(background_without_source, D, F, S, E)) :-
    findall(ID, unsourced_rule(BM, ID), IDs0), sort(IDs0, IDs),
    IDs \== [],
    atomic_list_concat(IDs, ', ', Shown),
    length(IDs, N),
    le_msg(background_without_source_desc, [program-P, count-N, rules-Shown], D),
    le_msg(background_without_source_fix, [], F).

unsourced_rule(BM, ID) :-
    le_kbs:template_of(BM, Fn, A, _, _),
    functor(H, Fn, A),
    current_predicate(BM:Fn/A),
    le_kbs:kb_own_predicate(BM, H),
    clause(BM:H, B, Ref), B \== true,
    BM:le_source_info(Ref, _, _, ID0),
    ( ID0 == main -> format(atom(ID), "~w", [Fn]) ; ID = ID0 ),
    \+ ( current_predicate(BM:le_rule_provenance/2), BM:le_rule_provenance(ID0, _) ).

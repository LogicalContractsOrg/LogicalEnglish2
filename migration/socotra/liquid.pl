/** <module> A reader for the Liquid subset of Socotra (classic) product scripts

    Parses a Liquid template into statements:

        assign(Var, Expr)
        output(Expr)                        {{ expr | filter: args ... }}
        if([Cond-Block, ...], ElseBlock)    if/elsif/else, and case/when/else
        for(Var, Collection, Block)
        text                                (literal text: ignored)

    Expr = filtered(Primary, [filter(Name, Args), ...])
    Primary = num(N) | str(S) | nil | bool(B) | path(Root, [Step, ...])
    Step = key(Name) | index(N) | index_expr(Primary) | first | last | size
    Cond = cmp(Op, Expr, Expr) | contains(Expr, Expr) | truthy(Expr)
         | and(C, C) | or(C, C)

    Comments are dropped (their content is not parsed). The reader is lenient
    where the reference Liquid is not, in the same ways as the oracle's
    normalisation (oracle.py): a number written `.05`, a `{% case x}` missing
    its `%`, parentheses around a condition. These forms occur in the public
    product library; how Socotra's own engine reads them was not checked.
*/

:- module(liquid, [liquid_parse/2, liquid_parse_file/2, liquid_normalize/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(dcg/basics)).

liquid_parse_file(File, Stmts) :-
    read_file_to_string(File, S, [encoding(utf8)]),
    liquid_parse(S, Stmts).

%!  liquid_normalize(+Text, -Normalized) is det.
%
%   The source fixes the oracle applies too (a form the reference Liquid
%   rejects; how Socotra's engine reads it was not checked).
liquid_normalize(Text, Norm) :-
    string_codes(Text, Cs0),
    fix_case_brace(Cs0, Cs1),
    string_codes(Norm, Cs1).

%   `{% case exposure_v.state}` -> `{% case exposure_v.state %}`
fix_case_brace([], []).
fix_case_brace([0'{, 0'%|Rest], Out) :-
    phrase((blanks, "case", string(Tag0), "}"), Rest, After),
    \+ memberchk(0'\n, Tag0), \+ memberchk(0'%, Tag0), !,
    append([`{% case`, Tag0, ` %}`], Fixed),
    fix_case_brace(After, Out0),
    append(Fixed, Out0, Out).
fix_case_brace([C|Cs], [C|Out]) :- fix_case_brace(Cs, Out).

%!  liquid_parse(+Text, -Statements) is det.
liquid_parse(Text0, Stmts) :-
    liquid_normalize(Text0, Text),
    string_codes(Text, Codes),
    phrase(segments(Segs), Codes),
    drop_comments(Segs, Segs1),
    parse_block(Segs1, Stmts, [], _End).

		 /*******************************
		 *           SEGMENTS           *
		 *******************************/

segments([S|Ss]) --> segment(S), !, segments(Ss).
segments([]) --> [].

segment(output(Codes)) --> "{{", opt_dash, string(Codes0), opt_dash_end, "}}", !, { trim(Codes0, Codes) }.
segment(tag(Codes)) --> "{%", opt_dash, string(Codes0), opt_dash_end, "%}", !, { trim(Codes0, Codes) }.
segment(text) --> [_], text_rest.

text_rest, [0'{] --> "{", !.
text_rest --> [C], { C \== 0'{ }, !, text_rest.
text_rest --> [].

opt_dash --> "-", !.
opt_dash --> [].
opt_dash_end, "%}" --> "-%}", !.
opt_dash_end, "}}" --> "-}}", !.
opt_dash_end --> [].

trim(Cs0, Cs) :-
    string_codes(S0, Cs0), normalize_space(codes(Cs), S0).

%   {% comment %} ... {% endcomment %}: dropped with everything in between.
drop_comments([], []).
drop_comments([tag(T)|Ss], Out) :-
    tag_name(T, comment), !,
    skip_to_endcomment(Ss, Rest),
    drop_comments(Rest, Out).
drop_comments([text|Ss], Out) :- !, drop_comments(Ss, Out).
drop_comments([S|Ss], [S|Out]) :- drop_comments(Ss, Out).

skip_to_endcomment([], []).
skip_to_endcomment([tag(T)|Ss], Ss) :- tag_name(T, endcomment), !.
skip_to_endcomment([_|Ss], Rest) :- skip_to_endcomment(Ss, Rest).

tag_name(Codes, Name) :-
    phrase((blanks, identifier(Name0), remainder(_)), Codes),
    atom_codes(Name, Name0).

		 /*******************************
		 *          STATEMENTS          *
		 *******************************/

%   parse_block(+Segs, -Stmts, +Stops, -EndTag): statements up to one of the
%   tags named in Stops (EndTag = tag(Name, Args, RestSegs)) or the end.
parse_block([], [], _, eof).
parse_block([S|Ss], Stmts, Stops, End) :-
    (   S = tag(T), tag_parts(T, Name, Args), memberchk(Name, Stops)
    ->  Stmts = [], End = tag(Name, Args, Ss)
    ;   parse_stmt(S, Ss, Stmt, Rest)
    ->  ( Stmt == skip -> Stmts = More ; Stmts = [Stmt|More] ),
        parse_block(Rest, More, Stops, End)
    ;   S = tag(T), string_codes(TS, T),
        Stmts = [unsupported(TS)|More],
        parse_block(Ss, More, Stops, End)
    ).

tag_parts(T, Name, Args) :-
    phrase((blanks, identifier(N0), blanks, remainder(A)), T),
    atom_codes(Name, N0), Args = A.

parse_stmt(output(Codes), Ss, output(E), Ss) :- !,
    expr_codes(Codes, E).
parse_stmt(tag(T), Ss, Stmt, Rest) :-
    tag_parts(T, Name, Args),
    tag_stmt(Name, Args, Ss, Stmt, Rest).

tag_stmt(assign, Args, Ss, assign(Var, E), Ss) :- !,
    phrase((blanks, identifier(V0), blanks, "=", blanks, remainder(ECs)), Args),
    atom_codes(Var, V0),
    expr_codes(ECs, E).
tag_stmt(if, Args, Ss, if(Branches, Else), Rest) :- !,
    cond_codes(Args, C),
    parse_block(Ss, B, [elsif, else, endif], End),
    if_rest(End, [C-B], Branches, Else, Rest).
tag_stmt(unless, Args, Ss, if([not(C)-B], Else), Rest) :- !,
    cond_codes(Args, C),
    parse_block(Ss, B, [else, endunless], End),
    (   End = tag(else, _, S1)
    ->  parse_block(S1, Else, [endunless], tag(endunless, _, Rest))
    ;   End = tag(endunless, _, Rest), Else = []
    ).
tag_stmt(case, Args, Ss, if(Branches, Else), Rest) :- !,
    expr_codes(Args, Subject),
    skip_to_when(Ss, Ss1),
    case_rest(Ss1, Subject, Branches, Else, Rest).
tag_stmt(for, Args, Ss, for(Var, Coll, B), Rest) :- !,
    phrase((blanks, identifier(V0), blanks, "in", blanks, remainder(CCs)), Args),
    atom_codes(Var, V0),
    expr_codes(CCs, Coll),
    parse_block(Ss, B, [endfor], tag(endfor, _, Rest)).
tag_stmt(raw, _, Ss, skip, Rest) :- !,
    append(_, [tag(T)|Rest], Ss), tag_name(T, endraw), !.

if_rest(tag(elsif, Args, Ss), Acc, Branches, Else, Rest) :- !,
    cond_codes(Args, C),
    parse_block(Ss, B, [elsif, else, endif], End),
    if_rest(End, [C-B|Acc], Branches, Else, Rest).
if_rest(tag(else, _, Ss), Acc, Branches, Else, Rest) :- !,
    parse_block(Ss, Else, [endif], tag(endif, _, Rest)),
    reverse(Acc, Branches).
if_rest(tag(endif, _, Rest), Acc, Branches, [], Rest) :-
    reverse(Acc, Branches).

skip_to_when(Ss, Ss) :- Ss = [tag(T)|_], tag_parts(T, N, _), memberchk(N, [when, else, endcase]), !.
skip_to_when([_|Ss], Out) :- skip_to_when(Ss, Out).
skip_to_when([], []).

case_rest([tag(T)|Ss], Subject, [C-B|Bs], Else, Rest) :-
    tag_parts(T, when, Args), !,
    when_values(Args, Vals),
    maplist(case_cmp(Subject), Vals, Cs),
    or_all(Cs, C),
    parse_block(Ss, B, [when, else, endcase], End),
    (   End = tag(when, WA, S1)
    ->  string_codes(WAs, WA), format(codes(WT), "when ~s", [WAs]),
        case_rest([tag(WT)|S1], Subject, Bs, Else, Rest)
    ;   End = tag(else, _, S1)
    ->  Bs = [], parse_block(S1, Else, [endcase], tag(endcase, _, Rest))
    ;   End = tag(endcase, _, Rest), Bs = [], Else = []
    ).
case_rest([tag(T)|Ss], _, [], Else, Rest) :-
    tag_parts(T, else, _), !,
    parse_block(Ss, Else, [endcase], tag(endcase, _, Rest)).
case_rest([tag(T)|Rest], _, [], [], Rest) :-
    tag_parts(T, endcase, _), !.

case_cmp(Subject, V, cmp(==, Subject, V)).

or_all([C], C) :- !.
or_all([C|Cs], or(C, R)) :- or_all(Cs, R).

when_values(Args, Vals) :-
    phrase(when_list(Vals), Args).

when_list([E|Es]) --> blanks, primary_tok(P), { E = filtered(P, []) }, blanks,
    ( ( "," ; "or" ) -> when_list(Es) ; { Es = [] } ).

		 /*******************************
		 *         EXPRESSIONS          *
		 *******************************/

expr_codes(Codes, E) :-
    (   phrase((blanks, filtered(E), blanks), Codes)
    ->  true
    ;   string_codes(S, Codes), E = unparsed(S)
    ).

cond_codes(Codes0, C) :-
    exclude(paren, Codes0, Codes),          % a lenient reading of (a or b) and c
    (   phrase((blanks, condition(C), blanks), Codes)
    ->  true
    ;   string_codes(S, Codes0), C = unparsed(S)
    ).

paren(0'().
paren(0')).

%   Liquid's and/or: right-associative, no precedence between them.
condition(C) --> comparison(C1), blanks,
    (   "and", blank1 -> blanks, condition(C2), { C = and(C1, C2) }
    ;   "or", blank1 -> blanks, condition(C2), { C = or(C1, C2) }
    ;   { C = C1 }
    ).

blank1, [C] --> [C], { code_type(C, space) }.

comparison(C) --> filtered(A), blanks,
    (   cmp_op(Op) -> blanks, filtered(B), { C = cmp(Op, A, B) }
    ;   "contains", blank1 -> blanks, filtered(B), { C = contains(A, B) }
    ;   { C = truthy(A) }
    ).

cmp_op(==) --> "==".
cmp_op(\=) --> "!=".
cmp_op(\=) --> "<>".
cmp_op(>=) --> ">=".
cmp_op(=<) --> "<=".
cmp_op(>) --> ">".
cmp_op(<) --> "<".

filtered(filtered(P, Fs)) --> primary_tok(P), blanks, filters(Fs).

filters([F|Fs]) --> "|", blanks, filter(F), !, blanks, filters(Fs).
filters(Fs) --> "|", blanks, filters(Fs).            % an empty filter (`| |`): skipped
filters([]) --> [].

filter(filter(Name, Args)) -->
    identifier(N0), { atom_codes(Name, N0) }, blanks,
    (   ":" -> blanks, filter_args(Args) ; { Args = [] } ).

filter_args([A|As]) --> primary_tok(A), blanks, ( "," -> blanks, filter_args(As) ; { As = [] } ).

primary_tok(str(S)) --> "\"", string_without(`"`, Cs), "\"", !, { string_codes(S, Cs) }.
primary_tok(str(S)) --> "'", string_without(`'`, Cs), "'", !, { string_codes(S, Cs) }.
primary_tok(num(N)) --> number_tok(N), !.
primary_tok(P) --> identifier(I0), { atom_codes(I, I0) },
    (   { memberchk(I, [nil, null]) } -> { P = nil }
    ;   { I == true } -> { P = bool(true) }
    ;   { I == false } -> { P = bool(false) }
    ;   { memberchk(I, [blank, empty]) } -> { P = empty }
    ;   steps(Ss), { P = path(I, Ss) }
    ).

number_tok(N) --> "-", !, unsigned(N0), { N is -N0 }.
number_tok(N) --> unsigned(N).

unsigned(N) --> digits1(I), ".", digits1(F), !,
    { append([I, `.`, F], Cs), number_codes(N, Cs) }.
unsigned(N) --> ".", digits1(F), !, { append(`0.`, F, Cs), number_codes(N, Cs) }.   % .05
unsigned(N) --> digits1(I), { number_codes(N, I) }.

digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].

steps([S|Ss]) --> ".", identifier(I0), !, { atom_codes(I, I0), step_key(I, S) }, steps(Ss).
steps([S|Ss]) --> "[", blanks, ( unsigned(N), { integer(N) } -> { S = index(N) } ; primary_tok(P), { S = index_expr(P) } ), blanks, "]", !, steps(Ss).
steps([]) --> [].

step_key(first, first) :- !.
step_key(last, last) :- !.
step_key(size, size) :- !.
step_key(I, key(I)).

%   Liquid identifiers: letters, digits, _ and -, and they may start with a
%   digit (Socotra field names like 10_year_felony_conviction).
identifier([C|Cs]) --> [C], { id_start(C) }, id_rest(Cs).
id_start(C) :- code_type(C, alnum) ; C == 0'_.
id_rest([C|Cs]) --> [C], { code_type(C, alnum) ; C == 0'_ ; C == 0'- }, !, id_rest(Cs).
id_rest([]) --> [].

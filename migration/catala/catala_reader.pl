:- module(catala_reader,
          [ read_catala_file/2,          % +File, -catala(Lang, Items)
            read_catala_text/3,          % +Lang, +Text, -Items
            catala_lang/2,               % +File, -Lang
            code_tokens/3                % +Lang, +Lines, -Tokens (for tests)
          ]).
/** <module> Catala's surface language, read in Prolog

The reader of roadmap.md §5.4 and §8, Phase 3c: a literate Catala file
(`.catala_en`, `.catala_fr`), its law text, headings and directives, and its
code blocks, read after the compiler's own lexer and grammar
(compiler/surface/lexer_en.cppo.ml, lexer_fr.cppo.ml, parser.mly of
https://github.com/CatalaLang/catala, copyright Inria and contributors,
Apache License 2.0; at release 1.2.0). The keywords of the two dialects and
the precedences are theirs; no file of the compiler is copied. Both dialects
give one tree; keywords are kept by their English names.

The tree:

    catala(Lang, Items)
      Items: heading(Level, Title, Line) | text(Text, Line)
           | directive(module(M, External) | using(M, Alias) | include(F), Line)
           | code(Kind, CodeItems, Line)          Kind: code | metadata
      CodeItems:
        scope_decl(Name, Decls, Attrs, Line)
            Decls: var(Name, IO, Output, Type, Params, States, Line)
                   IO: input | context | internal; Output: true | false
                 | sub(Name, Scope, Output, Line)
        struct_decl(Name, Fields, Line)          Fields: field(Name, Type, Params)
        enum_decl(Name, Cases, Line)             Cases: case(C, Type | none)
        topdef(Name, Type, Params, Expr | none, Line)
        abstract_type(Name, Line)
        scope_use(Name, Cond | none, ScopeItems, Attrs, Line)
            ScopeItems: def(Label, Exc, VarPath, Params, State, Cond, Expr, Line)
                      | rule(Label, Exc, VarPath, Params, State, Cond, Fulfilled, Line)
                      | assertion(Expr, Line) | date_rounding(up | down, Line)
            Label: none | L; Exc: none | unlabeled | to(L)
      Types: prim(integer | money | decimal | date | duration | boolean | condition)
           | named(Path, Name) | list(T) | option(T) | tuple(Ts) | func(Args, T)
      Expressions: lit(int(I) | dec(Num, Text) | money(Cents) | date(Y, M, D)
                       | bool(B) | percent(Num) | dur(N, year | month | day))
           | id(Path, Name, State) | dot(E, Path, Name) | tuple_get(E, N)
           | call(F, Args) | builtin(B) | scope_call(Path, Scope, Fields)
           | inject(Path, C, E | none) | struct(Path, S, Fields)
           | binop(Op, A, B) | unop(Op, A) | if(C, T, E) | let(Ids, E1, E2)
           | match(E, Arms) | test_case(E, Path, C, Ids) | replace(E, Fields)
           | list(Es) | tuple(Es) | contains(L, E) | sum(T, E)
           | maxmin(max | min, E, Default) | exists(Ids, L, E) | forall(Ids, L, E)
           | filter(Ids, L, E) | map(Ids, L, E) | map_filter(Ids, L, F, M)
           | find(Ids, L, E) | argext(max | min, Ids, L, E, Default)
           | fold(Acc, Ids, L, Init, E) | sort(Order, Ids, L, Crit)
           | assert_in(C, E)
           Arms: arm(Path, C, Ids, E) | wildcard(E)
*/

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(dcg/basics), [digits//1, blanks//0]).

		 /*******************************
		 *            FILES             *
		 *******************************/

%!  catala_lang(+File, -Lang) is semidet.
catala_lang(File, Lang) :-
    file_name_extension(_, Ext, File),
    (   Ext == catala_en -> Lang = en
    ;   Ext == catala_fr -> Lang = fr
    ).

%!  read_catala_file(+File, -Tree) is det.
read_catala_file(File, catala(Lang, Items)) :-
    (   catala_lang(File, Lang) -> true
    ;   throw(error(domain_error(catala_file, File), _))
    ),
    read_file_to_string(File, Text, []),
    read_catala_text(Lang, Text, Items).

%!  read_catala_text(+Lang, +Text, -Items) is det.
%
%   The literate structure first (law text, headings, directives, code
%   blocks between ```catala and ```), then each code block tokenized and
%   parsed. A syntax error throws catala_syntax(Message, Line).
read_catala_text(Lang, Text, Items) :-
    split_string(Text, "\n", "\r", Lines0),
    numbered(Lines0, 1, Lines),
    literate(Lines, Lang, Items).

numbered([], _, []).
numbered([L|Ls], N, [N-L|NLs]) :- N1 is N + 1, numbered(Ls, N1, NLs).

literate([], _, []).
literate([N-L|Ls], Lang, Items) :-
    (   code_fence(L, Kind)
    ->  code_lines(Ls, Code, Rest),
        code_tokens(Lang, Code, Tokens),
        catch(phrase(code_items(Lang, CodeItems), Tokens, Left), E, ( Left = [], throw(E) )),
        (   Left == [] -> true
        ;   Left = [T|_], token_line(T, TL), token_text(T, TT),
            throw(catala_syntax(format("unexpected ~w", [TT]), TL))
        ),
        Items = [code(Kind, CodeItems, N)|Items1],
        literate(Rest, Lang, Items1)
    ;   string_concat("#", _, L), \+ sub_string(L, 0, _, _, "#[")
    ->  heading(L, Level, Title),
        Items = [heading(Level, Title, N)|Items1],
        literate(Ls, Lang, Items1)
    ;   string_concat("> ", D, L), directive(Lang, D, Dir)
    ->  Items = [directive(Dir, N)|Items1],
        literate(Ls, Lang, Items1)
    ;   split_string(L, "", " \t", [""])
    ->  literate(Ls, Lang, Items)
    ;   Items = [text(L, N)|Items1],
        literate(Ls, Lang, Items1)
    ).

code_fence(L, Kind) :-
    split_string(L, "", " \t", [S]),
    (   S == "```catala" -> Kind = code
    ;   S == "```catala-metadata" -> Kind = metadata
    ;   S == "```catala-test-inputs" -> Kind = code
    ;   S == "```catala-test" -> Kind = code
    ).

code_lines([], [], []).
code_lines([N-L|Ls], Code, Rest) :-
    (   split_string(L, "", " \t", ["```"])
    ->  Code = [], Rest = Ls
    ;   Code = [N-L|Code1], code_lines(Ls, Code1, Rest)
    ).

heading(L, Level, Title) :-
    string_codes(L, Cs), hashes(Cs, 0, Level, Rest),
    string_codes(T0, Rest), split_string(T0, "", " \t", [Title]).

hashes([0'#|Cs], N0, N, Rest) :- !, N1 is N0 + 1, hashes(Cs, N1, N, Rest).
hashes(Cs, N, N, Cs).

directive(Lang, D0, Dir) :-
    split_string(D0, "", " \t", [D]),
    split_string(D, " \t", " \t", Ws0), exclude(==(""), Ws0, Ws),
    (   Lang == en
    ->  (   Ws = ["Module", M|Ex] -> atom_string(MA, M), ( Ex = ["external"] -> E = true ; E = false ), Dir = module(MA, E)
        ;   Ws = ["Using", M, "as", A] -> atom_string(MA, M), atom_string(AA, A), Dir = using(MA, AA)
        ;   Ws = ["Using", M] -> atom_string(MA, M), Dir = using(MA, MA)
        ;   string_concat("Include:", F0, D) -> split_string(F0, "", " ", [F]), Dir = include(F)
        )
    ;   (   Ws = ["Module", M|Ex] -> atom_string(MA, M), ( Ex = ["externe"] -> E = true ; E = false ), Dir = module(MA, E)
        ;   Ws = ["Usage", "de", M, "en", "tant", "que", A] -> atom_string(MA, M), atom_string(AA, A), Dir = using(MA, AA)
        ;   Ws = ["Usage", "de", M] -> atom_string(MA, M), Dir = using(MA, MA)
        ;   string_concat("Inclusion:", F0, D) -> split_string(F0, "", " ", [F]), Dir = include(F)
        )
    ).


		 /*******************************
		 *            LEXER             *
		 *******************************/

%!  code_tokens(+Lang, +Lines, -Tokens) is det.
%
%   Tokens: t(Token, Line), Token one of kw(K) (K the keyword's English
%   name), uid(A), lid(A), lit(L), str(S), p(P), attr(Name).
code_tokens(Lang, Lines, Tokens) :-
    foldl(line_tokens(Lang), Lines, Tokens0, []),
    keywords(Lang, Tokens0, Tokens).

line_tokens(Lang, N-L, Ts0, Ts) :-
    string_codes(L, Cs),
    (   phrase(ltoks(Lang, N, Ts0, Ts), Cs) -> true
    ;   throw(catala_syntax(format("cannot read the line: ~s", [Cs]), N))
    ).

ltoks(_, _, Ts, Ts) --> blanks_h, eos, !.
ltoks(Lang, N, Ts0, Ts) --> blanks_h, ltok(Lang, N, Ts0, Ts1), !, ltoks(Lang, N, Ts1, Ts).

eos([], []).
blanks_h --> [C], { C == 0' ; C == 0'\t ; C == 0xA0 ; C == 0x202F }, !, blanks_h.
blanks_h --> [].

%   #[test] and other attributes: their name kept, their value skipped.
ltok(_, N, [t(attr(A), N)|Ts], Ts) --> "#[", !, attr_name(Cs), { atom_codes(A, Cs) }, skip_to(0']).
ltok(_, _, Ts, Ts) --> "#", !, rest_of_line.
ltok(_, N, [t(str(S), N)|Ts], Ts) --> "\"", !, string_chars(Cs), { string_codes(S, Cs) }.
ltok(_, N, [t(lit(date(Y, M, D)), N)|Ts], Ts) -->
    "|", digits(YC), "-", digits(MC), "-", digits(DC), "|", !,
    { number_codes(Y, YC), number_codes(M, MC), number_codes(D, DC) }.
ltok(en, N, [t(lit(money(Cents)), N)|Ts], Ts) --> "$", !, blanks_h, money_en(Cents).
ltok(fr, N, [t(lit(money(Cents)), N)|Ts], Ts) --> money_fr(Cents), !.
ltok(Lang, N, [t(lit(L), N)|Ts], Ts) --> number(Lang, L), !.
ltok(_, N, [t(p(P), N)|Ts], Ts) --> punct(P), !.
ltok(_, N, [t(T, N)|Ts], Ts) --> ident(T), !.

attr_name([C|Cs]) --> [C], { code_type(C, alnum) ; C == 0'_ ; C == 0'. }, !, attr_name(Cs).
attr_name([]) --> [].

skip_to(C) --> [C], !.
skip_to(C) --> [_], !, skip_to(C).
skip_to(_) --> [].

rest_of_line --> [_], !, rest_of_line.
rest_of_line --> [].

string_chars([]) --> "\"", !.
string_chars([C|Cs]) --> [C], string_chars(Cs).

%   $350,000 or $1,234.56: the amount in cents.
money_en(Cents) -->
    digits(D0), { D0 \== [] }, groups(0',, G), ( ".", digits(F), { F \== [] } -> [] ; { F = [] } ),
    { append(D0, G, IC), number_codes(I, IC), cents(F, C), Cents is I * 100 + C }.

%   1 234,56 € (a space, or a narrow space, between the groups).
money_fr(Cents) -->
    digits(D0), { D0 \== [] }, fr_groups(G), ( ",", digits(F), { F \== [] } -> [] ; { F = [] } ),
    blanks_h, "€",
    { append(D0, G, IC), number_codes(I, IC), cents(F, C), Cents is I * 100 + C }.

groups(Sep, G) --> [Sep], digits(D), { length(D, 3) }, !, groups(Sep, G1), { append(D, G1, G) }.
groups(_, []) --> [].

fr_groups(G) --> [S], { S == 0' ; S == 0xA0 ; S == 0x202F }, digits(D), { length(D, 3) }, !, fr_groups(G1), { append(D, G1, G) }.
fr_groups([]) --> [].

cents([], 0) :- !.
cents([A], C) :- !, C is (A - 0'0) * 10.
cents([A, B|_], C) :- C is (A - 0'0) * 10 + (B - 0'0).

%   An integer, a decimal (1.5; in French 1,5), a percentage (20%).
number(Lang, L) -->
    digits(I), { I \== [] },
    (   { Lang == en -> Sep = 0'. ; Sep = 0', }, [Sep], digits(F), { F \== [] }
    ->  { append(I, [0'.|F], NC), number_codes(Num, NC), atom_codes(Txt, NC) },
        ( "%" -> { L = percent(Num) } ; { L = dec(Num, Txt) } )
    ;   { number_codes(Num, I) },
        ( "%" -> { L = percent(Num) } ; { L = int(Num) } )
    ).

punct(P) --> [A, B], { memberchk([A, B]-P, [`--`-'--', `>=`-'>=', `<=`-'<=', `!=`-'!=', `++`-'++']) }, !.
punct(P) --> [C], { memberchk(C, `()[]{},;:.+-*/<>=`), atom_codes(P, [C]) }.

%   A word: a capitalised one is an identifier of a type, a scope, a
%   constructor or a module; a lowercase one a variable, or a keyword
%   (keywords/3 merges the words of a keyword of several).
ident(T) -->
    [C], { code_type(C, alpha) }, ident_rest(Cs),
    { atom_codes(A, [C|Cs]),
      (   code_type(C, upper) -> T = uid(A) ; T = lid(A) ) }.

ident_rest([C|Cs]) --> [C], { code_type(C, alnum) ; C == 0'_ ; C == 0'\' }, !, ident_rest(Cs).
ident_rest([]) --> [].

%   The keywords of each dialect (lexer_en.cppo.ml, lexer_fr.cppo.ml), by
%   their words, longest first.
keywords(Lang, Ts0, Ts) :-
    findall(Ws-K, kw_words(Lang, K, Ws), Pairs0),
    predsort(longer_first, Pairs0, Pairs),
    merge_kws(Ts0, Pairs, Ts).

longer_first(O, Ws1-K1, Ws2-K2) :-
    length(Ws1, L1), length(Ws2, L2),
    (   L1 > L2 -> O = (<) ; L1 < L2 -> O = (>) ; compare(O, Ws1-K1, Ws2-K2) ).

merge_kws([], _, []).
merge_kws(Ts0, Pairs, [t(kw(K), N)|Ts]) :-
    Ts0 = [t(lid(_), N)|_],
    member(Ws-K, Pairs), words_prefix(Ws, Ts0, Rest), !,
    merge_kws(Rest, Pairs, Ts).
merge_kws([T|Ts0], Pairs, [T|Ts]) :- merge_kws(Ts0, Pairs, Ts).

words_prefix([], Rest, Rest).
words_prefix([W|Ws], [t(lid(W), _)|Ts], Rest) :- words_prefix(Ws, Ts, Rest).

kw_words(Lang, K, Ws) :- kw_(Lang, K, S), split_string(S, " ", "", Ss), maplist([X, Y]>>atom_string(Y, X), Ss, Ws).

kw_(en, scope, "scope").                kw_(fr, scope, "champ d'application").
kw_(en, consequence, "consequence").    kw_(fr, consequence, "conséquence").
kw_(en, data, "data").                  kw_(fr, data, "donnée").
kw_(en, depends, "depends on").         kw_(fr, depends, "dépend de").
kw_(en, declaration, "declaration").    kw_(fr, declaration, "déclaration").
kw_(en, context, "context").            kw_(fr, context, "contexte").
kw_(en, decreasing, "down").            kw_(fr, decreasing, "inférieur").
kw_(en, increasing, "up").              kw_(fr, increasing, "supérieur").
kw_(en, of, "of").                      kw_(fr, of, "de").
kw_(en, list, "list of").               kw_(fr, list, "liste de").
kw_(en, option, "optional of").         kw_(fr, option, "optionnel de").
kw_(en, contains, "contains").          kw_(fr, contains, "contient").
kw_(en, enumeration, "enumeration").    kw_(fr, enumeration, "énumération").
kw_(en, sum, "sum").                    kw_(fr, sum, "somme").
kw_(en, filled, "fulfilled").           kw_(fr, filled, "rempli").
kw_(en, definition, "definition").      kw_(fr, definition, "définition").
kw_(en, state, "state").                kw_(fr, state, "état").
kw_(en, label, "label").                kw_(fr, label, "étiquette").
kw_(en, exception, "exception").        kw_(fr, exception, "exception").
kw_(en, equals, "equals").              kw_(fr, equals, "égal à").
kw_(en, match, "match").                kw_(fr, match, "selon").
kw_(en, wildcard, "anything").          kw_(fr, wildcard, "n'importe quel").
kw_(en, type, "type").                  kw_(fr, type, "type").
kw_(en, with, "with pattern").          kw_(fr, with, "sous forme").
kw_(en, under_condition, "under condition"). kw_(fr, under_condition, "sous condition").
kw_(en, if, "if").                      kw_(fr, if, "si").
kw_(en, then, "then").                  kw_(fr, then, "alors").
kw_(en, else, "else").                  kw_(fr, else, "sinon").
kw_(en, condition, "condition").        kw_(fr, condition, "condition").
kw_(en, content, "content").            kw_(fr, content, "contenu").
kw_(en, structure, "structure").        kw_(fr, structure, "structure").
kw_(en, assertion, "assertion").        kw_(fr, assertion, "assertion").
kw_(en, with_v, "with").                kw_(fr, with_v, "avec").
kw_(en, for, "for").                    kw_(fr, for, "pour").
kw_(en, all, "all").                    kw_(fr, all, "tout").
kw_(en, we_have, "we have").            kw_(fr, we_have, "on a").
kw_(en, rule, "rule").                  kw_(fr, rule, "règle").
kw_(en, let, "let").                    kw_(fr, let, "soit").
kw_(en, exists, "exists").              kw_(fr, exists, "existe").
kw_(en, in, "in").                      kw_(fr, in, "dans").
kw_(en, among, "among").                kw_(fr, among, "parmi").
kw_(en, combine, "combine").            kw_(fr, combine, "combine").
kw_(en, map_each, "map each").          kw_(fr, map_each, "transforme chaque").
kw_(en, to, "to").                      kw_(fr, to, "en").
kw_(en, such, "such").                  kw_(fr, such, "tel").
kw_(en, that, "that").                  kw_(fr, that, "que").
kw_(en, sort, "sort").                  kw_(fr, sort, "trie").
kw_(en, ascending, "in increasing order"). kw_(fr, ascending, "par ordre croissant").
kw_(en, descending, "in decreasing order"). kw_(fr, descending, "par ordre décroissant").
kw_(en, and_then, "and then").          kw_(fr, and_then, "puis").
kw_(en, and, "and").                    kw_(fr, and, "et").
kw_(en, or, "or").                      kw_(fr, or, "ou").
kw_(en, xor, "xor").                    kw_(fr, xor, "ou bien").
kw_(en, not, "not").                    kw_(fr, not, "non").
kw_(en, maximum, "maximum").            kw_(fr, maximum, "maximum").
kw_(en, minimum, "minimum").            kw_(fr, minimum, "minimum").
kw_(en, is, "is").                      kw_(fr, is, "est").
kw_(en, or_if_list_empty, "or if list empty"). kw_(fr, or_if_list_empty, "ou si liste vide").
kw_(en, but_replace, "but replace").    kw_(fr, but_replace, "mais en remplaçant").
kw_(en, initially, "initially").        kw_(fr, initially, "initialement").
kw_(en, year, "year").                  kw_(fr, year, "an").
kw_(en, month, "month").                kw_(fr, month, "mois").
kw_(en, day, "day").                    kw_(fr, day, "jour").
kw_(en, true, "true").                  kw_(fr, true, "vrai").
kw_(en, false, "false").                kw_(fr, false, "faux").
kw_(en, input, "input").                kw_(fr, input, "entrée").
kw_(en, output, "output").              kw_(fr, output, "résultat").
kw_(en, internal, "internal").          kw_(fr, internal, "interne").
kw_(en, date, "date").                  kw_(fr, date, "date").
kw_(en, external, "external").          kw_(fr, external, "externe").

%   Built-in types and functions (Localisation.lex_primitive_type,
%   lex_builtin).
prim_type(en, integer, integer).  prim_type(fr, entier, integer).
prim_type(en, money, money).      prim_type(fr, argent, money).
prim_type(en, decimal, decimal).  prim_type(fr, 'décimal', decimal).
prim_type(en, duration, duration). prim_type(fr, 'durée', duration).
prim_type(en, boolean, boolean).  prim_type(fr, 'booléen', boolean).
prim_type(en, code_location, position). prim_type(fr, position_source, position).

builtin(en, round, round).        builtin(fr, arrondi, round).
builtin(en, impossible, impossible). builtin(fr, impossible, impossible).
builtin(en, number, cardinal).    builtin(fr, nombre, cardinal).

builtin_constr(en, 'Present', present). builtin_constr(fr, 'Présent', present).
builtin_constr(_, 'Absent', absent).


		 /*******************************
		 *            PARSER            *
		 *******************************/

token_line(t(_, N), N).
token_text(t(T, _), X) :- ( T = kw(K) -> X = K ; T = p(P) -> X = P ; arg(1, T, X) -> true ; X = T ).

%   Tokens, by kind.
kw(K) --> [t(kw(K), _)].
p(P) --> [t(p(P), _)].
line(N), [t(T, N)] --> [t(T, N)].

expect_kw(K) --> kw(K), !.
expect_kw(K) --> peek_line(N), { throw(catala_syntax(format("expected ~w", [K]), N)) }.
expect_p(P) --> p(P), !.
expect_p(P) --> peek_line(N), { throw(catala_syntax(format("expected ~w", [P]), N)) }.

peek_line(N), [T] --> [T], !, { token_line(T, N) }.
peek_line(0) --> [].

lid(A) --> [t(lid(A), _)].

peek_uid, [T] --> [T], { T = t(uid(_), _) }.

%   A name after a dot: a variable, or a function of a module whose name is
%   also a keyword (Duration.sum), kept by the keyword's English name.
field_name(F) --> [t(lid(F), _)], !.
field_name(F) --> [t(kw(F), _)].
uid(A) --> [t(uid(A), _)].

%   Attributes before an item (#[test]).
attrs([A|As]) --> [t(attr(A), _)], !, attrs(As).
attrs([]) --> [].

code_items(Lang, [I|Is]) --> attrs(As), code_item(Lang, As, I), !, code_items(Lang, Is).
code_items(_, []) --> [].

code_item(Lang, As, scope_use(Name, Cond, Items, As, N)) -->
    line(N), kw(scope), !, uid(Name),
    ( kw(under_condition) -> expr(Lang, Cond) ; { Cond = none } ),
    expect_p(:), scope_items(Lang, Items).
code_item(Lang, _, struct_decl(Name, Fields, N)) -->
    line(N), kw(declaration), kw(structure), !, uid(Name), expect_p(:), struct_fields(Lang, Fields).
code_item(Lang, As, scope_decl(Name, Decls, As, N)) -->
    line(N), kw(declaration), kw(scope), !, uid(Name), expect_p(:), scope_decls(Lang, Decls).
code_item(Lang, _, enum_decl(Name, Cases, N)) -->
    line(N), kw(declaration), kw(enumeration), !, uid(Name), expect_p(:), enum_cases(Lang, Cases).
code_item(_, _, abstract_type(Name, N)) -->
    line(N), kw(declaration), kw(type), !, uid(Name), expect_p(:), expect_kw(external).
code_item(Lang, _, topdef(Name, Type, Params, Expr, N)) -->
    line(N), kw(declaration), lid(Name), !, expect_kw(content), typ(Lang, Type),
    depends(Lang, Params),
    ( kw(equals) -> expr(Lang, Expr) ; { Expr = none } ).

struct_fields(Lang, [F|Fs]) --> attrs(_), struct_field(Lang, F), !, struct_fields(Lang, Fs).
struct_fields(_, []) --> [].

struct_field(Lang, field(Name, Type, Params)) -->
    kw(data), !, lid(Name), expect_kw(content), typ(Lang, Type), depends(Lang, Params).
struct_field(Lang, field(Name, prim(condition), Params)) -->
    kw(condition), lid(Name), depends(Lang, Params).

enum_cases(Lang, [case(C, T)|Cs]) -->
    attrs(_), p('--'), !, uid(C), ( kw(content) -> typ(Lang, T) ; { T = none } ), enum_cases(Lang, Cs).
enum_cases(_, []) --> [].

scope_decls(Lang, [D|Ds]) --> attrs(_), scope_decl(Lang, D), !, scope_decls(Lang, Ds).
scope_decls(_, []) --> [].

scope_decl(Lang, D) -->
    line(N), io(IO0), out(Out), lid(Name),
    (   kw(content)
    ->  typ(Lang, T), depends(Lang, Ps), states(Ss),
        { ( IO0 == none -> ( Out == true -> IO = internal ; IO = internal ) ; IO = IO0 ),
          D = var(Name, IO, Out, T, Ps, Ss, N) }
    ;   kw(condition)
    ->  depends(Lang, Ps), states(Ss),
        { ( IO0 == none -> IO = internal ; IO = IO0 ),
          D = var(Name, IO, Out, prim(condition), Ps, Ss, N) }
    ;   kw(scope)
    ->  quident(Path, Sc), { D = sub(Name, scoped(Path, Sc), Out, N) }
    ).

io(input) --> kw(input), !.
io(context) --> kw(context), !.
io(internal) --> kw(internal), !.
io(none) --> [].

out(true) --> kw(output), !.
out(false) --> [].

states([S|Ss]) --> kw(state), !, lid(S), states(Ss).
states([]) --> [].

depends(Lang, Ps) -->
    kw(depends), !,
    (   p('(') -> var_contents(Lang, Ps), expect_p(')')
    ;   var_contents(Lang, Ps)
    ).
depends(_, []) --> [].

var_contents(Lang, [V-T|Ps]) --> lid(V), expect_kw(content), typ(Lang, T), ( p(',') -> var_contents(Lang, Ps) ; { Ps = [] } ).

%   Types.
typ(Lang, T) --> kw(list), !, typ(Lang, T0), { T = list(T0) }.
typ(Lang, T) --> kw(option), !, typ(Lang, T0), { T = option(T0) }.
typ(Lang, T) --> p('('), !, typs(Lang, Ts), expect_p(')'), { Ts = [T] -> true ; T = tuple(Ts) }.
typ(_, prim(date)) --> kw(date), !.
typ(_, prim(condition)) --> kw(condition), !.
typ(Lang, prim(P)) --> lid(A), { prim_type(Lang, A, P) }, !.
typ(_, named(Path, N)) --> quident(Path, N), !.
typ(_, any) --> kw(wildcard), !, ( kw(of) -> kw(type), lid(_) ; [] ).

typs(Lang, [T|Ts]) --> typ(Lang, T), ( p(',') -> typs(Lang, Ts) ; { Ts = [] } ).

quident(Path, N) --> uid(A), ( p('.'), peek_uid -> quident(P1, N), { Path = [A|P1] } ; { Path = [], N = A } ).

%   Scope items.
scope_items(Lang, [I|Is]) --> attrs(_), scope_item(Lang, I), !, scope_items(Lang, Is).
scope_items(_, []) --> [].

scope_item(Lang, Item) -->
    line(N), label(L), exc(E),
    (   kw(definition)
    ->  scope_var(Path), def_params(Ps), state(S), cond(Lang, C), expect_kw(equals), expr(Lang, X),
        { Item = def(L, E, Path, Ps, S, C, X, N) }
    ;   kw(rule)
    ->  scope_var(Path), def_params(Ps), state(S), cond(Lang, C),
        ( kw(not) -> expect_kw(filled), { F = false } ; expect_kw(filled), { F = true } ),
        { Item = rule(L, E, Path, Ps, S, C, F, N) }
    ).
scope_item(Lang, assertion(X, N)) --> line(N), kw(assertion), !, expr(Lang, X).
scope_item(Lang, date_rounding(D, N)) -->
    line(N), kw(date), lid(R), { builtin(Lang, R, round) }, !,
    ( kw(increasing) -> { D = up } ; kw(decreasing) -> { D = down } ).

label(L) --> kw(label), !, lid(L).
label(none) --> [].

exc(E) --> kw(exception), !, ( lid(L) -> { E = to(L) } ; { E = unlabeled } ).
exc(none) --> [].

scope_var([V|Vs]) --> lid(V), ( p('.') -> scope_var(Vs) ; { Vs = [] } ).

def_params(Ps) --> kw(of), !, lids(Ps).
def_params([]) --> [].

lids([L|Ls]) --> lid(L), ( p(',') -> lids(Ls) ; { Ls = [] } ).

state(S) --> kw(state), !, lid(S).
state(none) --> [].

cond(Lang, C) --> kw(under_condition), !, expr(Lang, C), expect_kw(consequence).
cond(_, none) --> [].


		 /*******************************
		 *          EXPRESSIONS         *
		 *******************************/

%   Precedence (parser.mly): the binding constructs (if, let, match,
%   exists, for all, list of ...) are loosest; then and/or/xor, which the
%   desugaring requires parenthesised when mixed (right-associative here);
%   comparisons; + - ++; * /; application (of), contains, with pattern, but
%   replace; unary not and minus; the dot.
expr(Lang, E) --> binding(Lang, E), !.
expr(Lang, E) --> logic(Lang, E).

binding(Lang, if(C, T, E)) --> kw(if), !, expr(Lang, C), expect_kw(then), expr(Lang, T), expect_kw(else), expr(Lang, E).
binding(Lang, let(Ids, E1, E2)) --> kw(let), !, mbinder(Ids), expect_kw(equals), expr(Lang, E1), expect_kw(in), expr(Lang, E2).
binding(Lang, match(E, Arms)) --> kw(match), !, expr(Lang, E), expect_kw(with), arms(Lang, Arms).
binding(Lang, exists(Ids, L, E)) --> kw(exists), !, mbinder(Ids), expect_kw(among), expr(Lang, L), expect_kw(such), expect_kw(that), expr(Lang, E).
binding(Lang, forall(Ids, L, E)) --> kw(for), !, expect_kw(all), mbinder(Ids), expect_kw(among), expr(Lang, L), expect_kw(we_have), expr(Lang, E).
binding(Lang, filter(Ids, L, E)) --> kw(list), mbinder(Ids), kw(among), !, expr(Lang, L), expect_kw(such), expect_kw(that), expr(Lang, E).
binding(Lang, M) -->
    kw(map_each), !, mbinder(Ids), expect_kw(among), expr(Lang, L),
    (   kw(such) -> expect_kw(that), expr(Lang, F), expect_kw(to), expr(Lang, X), { M = map_filter(Ids, L, F, X) }
    ;   expect_kw(to), expr(Lang, X), { M = map(Ids, L, X) }
    ).
binding(Lang, fold(Acc, Ids, L, Init, F)) -->
    kw(combine), !, expect_kw(all), mbinder(Ids), expect_kw(among), expr(Lang, L),
    expect_kw(in), mbinder(Acc), expect_kw(initially), expr(Lang, Init), expect_kw(with_v), expr(Lang, F).
binding(Lang, S) -->
    kw(sort), !,
    (   kw(all) -> mbinder(Ids), expect_kw(among), expr(Lang, L), order(O), expect_kw(of), crits(Lang, C), { S = sort(O, Ids, L, C) }
    ;   expr(Lang, L), order(O), { S = sort(O, [x], L, [id([], x, none)]) }
    ).
binding(Lang, X) -->
    kw(content), kw(of), !, mbinder(Ids), expect_kw(among), expr(Lang, L), expect_kw(such), expect_kw(that), expr(Lang, F),
    (   kw(is) -> minmax(MM), or_if_empty(Lang, D), { X = argext(MM, Ids, L, F, D) }
    ;   { X = find(Ids, L, F) }
    ).
binding(Lang, assert_in(C, E)) --> kw(assertion), !, expr(Lang, C), expect_kw(in), expr(Lang, E).

order(asc) --> kw(ascending), !.
order(desc) --> kw(descending).

crits(Lang, [E|Es]) --> logic(Lang, E), ( kw(and_then) -> crits(Lang, Es) ; { Es = [] } ).

mbinder([I]) --> lid(I), !.
mbinder(Is) --> p('('), lids(Is), expect_p(')').

arms(Lang, [A|As]) --> p('--'), !, arm(Lang, A), arms_more(Lang, As).
arms_more(Lang, [A|As]) --> p('--'), !, arm(Lang, A), arms_more(Lang, As).
arms_more(_, []) --> [].

arm(Lang, wildcard(E)) --> kw(wildcard), !, expect_p(:), expr(Lang, E).
arm(Lang, arm(Path, C, Ids, E)) --> quident(Path, C), ( kw(content) -> mbinder(Ids) ; { Ids = [] } ), expect_p(:), expr(Lang, E).

minmax(max) --> kw(maximum), !.
minmax(min) --> kw(minimum).

or_if_empty(Lang, D) --> kw(or_if_list_empty), !, expect_kw(then), expr(Lang, D).
or_if_empty(_, none) --> [].

%   and, or, xor: right-associative; a binding construct may follow.
logic(Lang, E) -->
    compare(Lang, A),
    (   logic_op(Op) -> rhs(Lang, B), { E = binop(Op, A, B) }
    ;   { E = A }
    ).
rhs(Lang, E) --> binding(Lang, E), !.
rhs(Lang, E) --> logic(Lang, E).

logic_op(and) --> kw(and), !.
logic_op(or) --> kw(or), !.
logic_op(xor) --> kw(xor).

compare(Lang, E) -->
    additive(Lang, A),
    (   cmp_op(Op) -> ( binding(Lang, B) -> [] ; additive(Lang, B) ), { E = binop(Op, A, B) }
    ;   { E = A }
    ).

cmp_op(Op) --> p(P), { memberchk(P-Op, ['>='-gte, '<='-lte, '>'-gt, '<'-lt, '='-eq, '!='-neq]) }.

additive(Lang, E) --> multiplicative(Lang, A), additive_rest(Lang, A, E).
additive_rest(Lang, A, E) -->
    p(P), { memberchk(P-Op, ['+'-add, '-'-sub, '++'-concat]) }, !,
    (   binding(Lang, B) -> { E = binop(Op, A, B) }
    ;   multiplicative(Lang, B), additive_rest(Lang, binop(Op, A, B), E)
    ).
additive_rest(_, E, E) --> [].

multiplicative(Lang, E) --> applied(Lang, A), multiplicative_rest(Lang, A, E).
multiplicative_rest(Lang, A, E) -->
    p(P), { memberchk(P-Op, ['*'-mult, '/'-div]) }, !,
    (   binding(Lang, B) -> { E = binop(Op, A, B) }
    ;   applied(Lang, B), multiplicative_rest(Lang, binop(Op, A, B), E)
    ).
multiplicative_rest(_, E, E) --> [].

%   f of a, b; l contains x; e with pattern C; e but replace {...}; and the
%   prefix forms sum T of e, maximum of l, output of S with {...}.
applied(Lang, E) --> kw(sum), !, ( typ(Lang, T) -> [] ; { T = none } ), expect_kw(of), applied(Lang, L), { E = sum(T, L) }.
applied(Lang, E) --> minmax(MM), kw(of), !, applied(Lang, L), or_if_empty(Lang, D), { E = maxmin(MM, L, D) }.
applied(Lang, E) --> kw(output), kw(of), !, quident(P, S), scope_args(Lang, Fs), { E = scope_call(P, S, Fs) }.
applied(Lang, E) --> unary(Lang, A), applied_rest(Lang, A, E).

applied_rest(Lang, A, E) --> kw(of), !, funargs(Lang, Args), applied_rest(Lang, call(A, Args), E).
applied_rest(Lang, A, E) --> kw(contains), !, unary(Lang, B), applied_rest(Lang, contains(A, B), E).
applied_rest(Lang, A, E) -->
    kw(with), peek_uid, !,                          % (not the `with pattern` of a match)
    quident(P, C), ( kw(content) -> mbinder(Ids) ; { Ids = [] } ),
    applied_rest(Lang, test_case(A, P, C, Ids), E).
applied_rest(Lang, A, E) -->
    kw(but_replace), !, expect_p('{'), struct_fields_lit(Lang, Fs), expect_p('}'),
    applied_rest(Lang, replace(A, Fs), E).
applied_rest(_, E, E) --> [].

funargs(Lang, [A|As]) --> funarg(Lang, A), ( p(',') -> funargs(Lang, As) ; { As = [] } ).
funarg(Lang, A) --> binding(Lang, A), !.
funarg(Lang, A) --> applied(Lang, A).          % (application binds tighter than * and /: `arrondi de x / y` is (arrondi de x) / y, parser.mly's %prec apply)

scope_args(Lang, Fs) --> kw(with_v), !, expect_p('{'), struct_fields_lit0(Lang, Fs), expect_p('}').
scope_args(_, []) --> [].

struct_fields_lit0(Lang, Fs) --> struct_fields_lit(Lang, Fs), !.
struct_fields_lit0(_, []) --> [].

struct_fields_lit(Lang, [F-E|Fs]) --> p('--'), lid(F), expect_p(:), expr(Lang, E), ( struct_fields_lit(Lang, Fs) -> [] ; { Fs = [] } ).

unary(Lang, unop(not, E)) --> kw(not), !, unary_operand(Lang, E).
unary(Lang, unop(minus, E)) --> p('-'), !, unary_operand(Lang, E).
unary(Lang, E) --> dotted(Lang, E).

unary_operand(Lang, E) --> binding(Lang, E), !.
unary_operand(Lang, E) --> unary(Lang, E).

dotted(Lang, E) --> atom(Lang, A), dot_rest(A, E).

dot_rest(A, E) --> p('.'), field_name(F), !, dot_rest(dot(A, [], F), E).
dot_rest(A, E) --> p('.'), [t(uid(M), _)], p('.'), [t(lid(F), _)], !, dot_rest(dot(A, [M], F), E).
dot_rest(A, E) --> p('.'), [t(lit(int(N)), _)], !, dot_rest(tuple_get(A, N), E).
dot_rest(E, E) --> [].

atom(_, lit(L)) --> [t(lit(L0), _)], !, unit_lit(L0, L).
atom(_, lit(bool(true))) --> kw(true), !.
atom(_, lit(bool(false))) --> kw(false), !.
atom(Lang, E) --> p('('), !, exprs(Lang, Es), expect_p(')'), { Es = [E0] -> E = E0 ; E = tuple(Es) }.
atom(Lang, list(Es)) --> p('['), !, list_body(Lang, Es), expect_p(']').
atom(Lang, E) --> [t(lid(A), _)], !, ( { builtin(Lang, A, B) } -> { E = builtin(B) } ; state(S), { E = id([], A, S) } ).
atom(Lang, E) --> quident(Path, U), !, uid_rest(Lang, Path, U, E).

uid_rest(_, Path, U, id(Path1, F, S)) --> p('.'), field_name(F), !, { append(Path, [U], Path1) }, state(S).
uid_rest(Lang, Path, U, struct(Path, U, Fs)) --> p('{'), !, struct_fields_lit(Lang, Fs), expect_p('}').
uid_rest(Lang, Path, U, inject(Path, C, X)) -->
    { ( Path == [], builtin_constr(Lang, U, C0) -> C = C0 ; C = U ) },
    ( kw(content) -> dotted_or_binding(Lang, X) ; { X = none } ).

dotted_or_binding(Lang, X) --> binding(Lang, X), !.
dotted_or_binding(Lang, X) --> unary(Lang, X).

unit_lit(int(N), dur(N, U)) --> duration_unit(U), !.
unit_lit(L, L) --> [].

duration_unit(year) --> kw(year).
duration_unit(month) --> kw(month).
duration_unit(day) --> kw(day).

exprs(Lang, [E|Es]) --> expr(Lang, E), ( p(',') -> exprs(Lang, Es) ; { Es = [] } ).

list_body(Lang, [E|Es]) --> expr(Lang, E), !, ( p(';') -> list_body(Lang, Es) ; { Es = [] } ).
list_body(_, []) --> [].
